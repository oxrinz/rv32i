const std = @import("std");
const tokens_script = @import("tokens.zig");
const Token = tokens_script.Token;
const TokenType = tokens_script.TokenType;
const c_ast = @import("../ast/c.zig");
const diagnostics = @import("../diagnostics.zig");
const testing = @import("../testing.zig");

pub const Parser = struct {
    tokens: []const Token,
    cursor: usize,
    allocator: std.mem.Allocator,

    pub fn init(tokens: []const Token, allocator: std.mem.Allocator) Parser {
        return Parser{
            .tokens = tokens,
            .cursor = 0,
            .allocator = allocator,
        };
    }

    pub fn parse(self: *Parser) !c_ast.Program {
        var function_array = std.ArrayList(c_ast.FunctionDeclaration).init(self.allocator);
        while (self.cursor < self.tokens.len - 1) {
            const func_decl = try self.parseDeclaration();
            try function_array.append(func_decl.function_declaration);
            self.cursor += 1;
        }
        return .{ .function = try function_array.toOwnedSlice() };
    }

    // TODO: can't start function with a left paren
    fn parseFunction(self: *Parser) !c_ast.FunctionDeclaration {
        try self.expect(.INT);
        self.cursor += 1;
        try self.expect(.IDENTIFIER);

        const identifier = self.curr().literal.?.string;

        self.cursor += 1;
        try self.expect(.LEFT_PAREN);
        self.cursor += 1;

        const params = try self.parseFunctionParams();

        try self.expect(.LEFT_BRACE);
        self.cursor += 1;

        const body = try self.parseBlock();
        self.cursor += 1;

        return .{
            .identifier = identifier,
            .params = params,
            .body = body,
        };
    }

    fn parseBlock(self: *Parser) !c_ast.Block {
        var function_body = std.ArrayList(c_ast.BlockItem).init(self.allocator);

        while (self.cursor < self.tokens.len - 1 and self.curr().type != .RIGHT_BRACE) {
            const block_item = try self.parseBlockItem();
            try function_body.append(block_item);
            self.cursor += 1;
        }

        return .{
            .block_items = try function_body.toOwnedSlice(),
        };
    }

    fn parseBlockItem(self: *Parser) !c_ast.BlockItem {
        switch (self.curr().type) {
            .INT => {
                return .{ .declaration = try self.parseDeclaration() };
            },
            else => return .{ .statement = try self.parseStatement() },
        }
    }

    fn parseDeclaration(self: *Parser) anyerror!c_ast.Declaration {
        try self.expect(.INT);
        self.cursor += 1;
        try self.expect(.IDENTIFIER);

        const identifier = self.curr().literal.?.string;
        self.cursor += 1;

        switch (self.curr().type) {
            .SEMICOLON => {
                return .{
                    .variable_declaration = .{
                        .identifier = identifier,
                        .initial = null,
                    },
                };
            },
            .LEFT_PAREN => {
                self.cursor += 1;

                const params = try self.parseFunctionParams();

                var body: ?c_ast.Block = null;
                if (self.curr().type != .SEMICOLON) {
                    self.cursor += 1;
                    body = try self.parseBlock();
                }

                return .{
                    .function_declaration = c_ast.FunctionDeclaration{
                        .identifier = identifier,
                        .params = params,
                        .body = body,
                    },
                };
            },
            else => {
                try self.expect(.EQUAL);
                self.cursor += 1;
                const expression = try self.parseExpression(0);

                return .{ .variable_declaration = .{ .identifier = identifier, .initial = expression.* } };
            },
        }
    }

    // fn parseIf(self: *Parser) c_ast.If {}

    fn parseStatement(self: *Parser) anyerror!c_ast.Statement {
        switch (self.curr().type) {
            .RETURN => {
                self.cursor += 1;

                // ??????????????
                // ??????????????
                const expr_ptr = try self.parseExpression(0);
                const expr = expr_ptr.*;
                self.allocator.destroy(expr_ptr);
                return .{
                    .ret = .{ .exp = expr },
                };
            },
            .IF => {
                self.cursor += 1;
                try self.expect(.LEFT_PAREN);
                self.cursor += 1;
                const condition = try self.parseExpression(0);
                try self.expect(.RIGHT_PAREN);
                self.cursor += 1;

                const then = try self.parseStatement();
                const then_ptr = try self.allocator.create(c_ast.Statement);
                then_ptr.* = then;

                var else_ptr: ?*c_ast.Statement = null;

                if (self.peek(1).type == .ELSE) {
                    self.cursor += 2;
                    const else_ = try self.parseStatement();
                    else_ptr = try self.allocator.create(c_ast.Statement);
                    else_ptr.?.* = else_;
                }
                return .{
                    .if_ = .{
                        .condition = condition.*,
                        .then = then_ptr,
                        .else_ = else_ptr,
                    },
                };
            },
            .LEFT_BRACE => {
                self.cursor += 1;
                const block = try self.parseBlock();
                return .{
                    .compound = block,
                };
            },
            .BREAK => {
                self.cursor += 1;
                return .{
                    .break_ = .{ .identifier = null },
                };
            },
            .CONTINUE => {
                self.cursor += 1;
                return .{
                    .continue_ = .{ .identifier = null },
                };
            },
            .WHILE => {
                self.cursor += 1;
                try self.expect(.LEFT_PAREN);
                const condition = try self.parseExpression(0);
                const body = try self.parseStatement();
                const body_ptr = try self.allocator.create(c_ast.Statement);
                body_ptr.* = body;
                return c_ast.Statement{
                    .while_ = .{
                        .body = body_ptr,
                        .identifier = null,
                        .condition = condition.*,
                    },
                };
            },
            .DO => {
                self.cursor += 1;
                const body = try self.parseStatement();
                const body_ptr = try self.allocator.create(c_ast.Statement);
                body_ptr.* = body;

                self.cursor += 1;
                try self.expect(.WHILE);
                self.cursor += 1;
                try self.expect(.LEFT_PAREN);
                const condition = try self.parseExpression(0);

                return c_ast.Statement{
                    .do_while = .{
                        .body = body_ptr,
                        .condition = condition.*,
                        .identifier = null,
                    },
                };
            },
            .FOR => {
                self.cursor += 1;
                try self.expect(.LEFT_PAREN);
                self.cursor += 1;

                var for_init: c_ast.ForInit = undefined;
                if (self.curr().type == .INT) {
                    const declaration = try self.parseDeclaration();
                    for_init = .{ .init_decl = declaration.variable_declaration };
                } else {
                    const expression = try self.parseExpression(0);
                    for_init = .{ .init_exp = expression.* };
                }

                var condition: ?*c_ast.Expression = null;
                if (self.curr().type != .RIGHT_PAREN) {
                    self.cursor += 1;
                    condition = try self.parseExpression(0);
                }

                var post: ?*c_ast.Expression = null;
                if (self.curr().type != .RIGHT_PAREN) {
                    self.cursor += 1;
                    post = try self.parseExpression(0);
                }

                self.cursor += 1;
                const body = try self.parseStatement();
                const body_ptr = try self.allocator.create(c_ast.Statement);
                body_ptr.* = body;

                return c_ast.Statement{
                    .for_ = .{
                        .init = for_init,
                        .condition = if (condition != null) condition.?.* else null,
                        .post = if (post != null) post.?.* else null,
                        .body = body_ptr,
                        .identifier = null,
                    },
                };
            },
            else => {
                const expr_ptr = try self.parseExpression(0);
                const expr = expr_ptr.*;
                self.allocator.destroy(expr_ptr);
                return .{
                    .exp = expr,
                };
            },
        }
    }

    fn parseExpression(self: *Parser, min_prec: i16) anyerror!*c_ast.Expression {
        var left = try self.parseFactor();

        while (self.cursor < self.tokens.len and
            tokens_script.is_binary_operator(self.curr().type) and
            self.precedence(self.curr()) >= min_prec)
        {
            const curr_prec = self.precedence(self.curr());

            if (self.curr().type == .EQUAL) {
                self.cursor += 1;
                const right = try self.parseExpression(curr_prec);

                const new_expr = try self.allocator.create(c_ast.Expression);
                new_expr.* = .{
                    .assignment = .{
                        .left = left,
                        .right = right,
                    },
                };

                left = new_expr;
            }
            // check inplace operators
            //
            else if (tokens_script.is_in_place_starter(self.curr().type) == true and self.peek(-1).type == .IDENTIFIER and self.peek(1).type == .EQUAL) {
                const operator = self.parseBinop();
                self.cursor += 1;
                try self.expect(.EQUAL);
                self.cursor += 1;

                const variable_expr = try self.allocator.create(c_ast.Expression);
                variable_expr.* = .{
                    .variable = .{ .identifier = self.peek(-3).literal.?.string },
                };

                const binary_expr = try self.allocator.create(c_ast.Expression);
                binary_expr.* = .{
                    .binary = .{
                        .operator = operator,
                        .left = variable_expr,
                        .right = try self.parseExpression(curr_prec),
                    },
                };

                const new_expr = try self.allocator.create(c_ast.Expression);
                new_expr.* = .{
                    .assignment = .{
                        .left = left,
                        .right = binary_expr,
                    },
                };

                left = new_expr;
            } else {
                const operator = self.parseBinop();
                self.cursor += 1;

                const right = try self.parseExpression(curr_prec + 1);

                const new_expr = try self.allocator.create(c_ast.Expression);
                new_expr.* = .{
                    .binary = .{
                        .operator = operator,
                        .left = left,
                        .right = right,
                    },
                };

                left = new_expr;
            }
        }

        return left;
    }

    fn parseFactor(self: *Parser) !*c_ast.Expression {
        var expr = try self.allocator.create(c_ast.Expression);

        switch (self.curr().type) {
            .NUMBER => {
                expr.* = .{
                    .constant = self.curr().literal.?.number,
                };
                self.cursor += 1;
            },
            .LEFT_PAREN => {
                self.cursor += 1;
                const inner_expr = try self.parseExpression(0);
                try self.expect(.RIGHT_PAREN);
                self.cursor += 1;

                expr = inner_expr;
            },
            .IDENTIFIER => {
                switch (self.peek(1).type) {
                    .LEFT_PAREN => {
                        self.cursor += 2;
                        expr.* = .{
                            .function_call = c_ast.FunctionCall{
                                .identifier = self.peek(-2).literal.?.string,
                                .args = try self.parseFunctionArgs(),
                            },
                        };
                    },
                    else => {
                        expr.* = .{
                            .variable = .{
                                .identifier = self.curr().literal.?.string,
                            },
                        };
                        self.cursor += 1;
                    },
                }
            },
            else => {
                const msg = try std.fmt.allocPrint(diagnostics.arena.allocator(), "Syntax error at line {}. Expected one of the following: NUMBER, LEFT_PAREN, IDENTIFIER. Got token type {}", .{
                    self.curr().line,
                    self.curr().type,
                });
                diagnostics.addError(msg, self.curr().line);
                return error.SyntaxError;
            },
        }

        return expr;
    }

    fn parseFunctionParams(self: *Parser) ![][]const u8 {
        if (self.curr().type == .RIGHT_PAREN) {
            self.cursor += 1;
            return &[_][]const u8{};
        }

        var param_list = std.ArrayList([]const u8).init(self.allocator);

        try self.expect(.INT);
        self.cursor += 1;
        try param_list.append(self.curr().literal.?.string);
        self.cursor += 1;

        while (self.curr().type != .RIGHT_PAREN) {
            try self.expect(.COMMA);
            self.cursor += 1;
            try self.expect(.INT);
            self.cursor += 1;
            try param_list.append(self.curr().literal.?.string);
            self.cursor += 1;
        }

        try self.expect(.RIGHT_PAREN);
        self.cursor += 1;

        return try param_list.toOwnedSlice();
    }

    fn parseFunctionArgs(self: *Parser) ![]*c_ast.Expression {
        if (self.curr().type == .RIGHT_PAREN) {
            self.cursor += 1;
            return &[_]*c_ast.Expression{};
        }
        var param_list = std.ArrayList(*c_ast.Expression).init(self.allocator);

        try param_list.append(try self.parseExpression(0));

        while (self.curr().type != .RIGHT_PAREN) {
            try self.expect(.COMMA);
            self.cursor += 1;
            try param_list.append(try self.parseExpression(0));
        }

        try self.expect(.RIGHT_PAREN);
        self.cursor += 1;

        return try param_list.toOwnedSlice();
    }

    fn parseBinop(self: *Parser) c_ast.BinaryOperator {
        switch (self.curr().type) {
            .PLUS => return .Add,
            .MINUS => return .Subtract,
            .STAR => return .Multiply,
            .SLASH => return .Divide,
            .PERCENTAGE => return .Remainder,

            .AMPERSAND => return .Bitwise_AND,
            .PIPE => return .Bitwise_OR,
            .CARET => return .Bitwise_XOR,
            .LEFT_SHIFT => return .Left_Shift,
            .RIGHT_SHIFT => return .Right_Shift,

            .LESS => return .Less,
            .LESS_EQUAL => return .Less_Or_Equal,
            .GREATER => return .Greater,
            .GREATER_EQUAL => return .Greater_Or_Equal,
            .EQUAL_EQUAL => return .Equal,
            .BANG_EQUAL => return .Not_Equal,
            .AMPERSAND_AMPERSAND => return .And,
            .PIPE_PIPE => return .Or,
            else => unreachable,
        }
    }

    fn precedence(self: *Parser, token: Token) i16 {
        _ = self;
        switch (token.type) {
            .EQUAL => return 1,
            .PIPE_PIPE => return 5,
            .AMPERSAND_AMPERSAND => return 10,
            .EQUAL_EQUAL, .BANG_EQUAL => return 30,
            .LESS, .LESS_EQUAL, .GREATER, .GREATER_EQUAL => return 35,
            .LEFT_SHIFT, .RIGHT_SHIFT => return 48,
            .AMPERSAND => return 47,
            .CARET => return 46,
            .PIPE => return 45,
            .PLUS, .MINUS => return 45,
            .STAR, .SLASH, .PERCENTAGE => return 50,
            else => unreachable,
        }
    }

    fn expect(self: *Parser, token_type: TokenType) !void {
        if (self.curr().type != token_type) {
            const msg = try std.fmt.allocPrint(diagnostics.arena.allocator(), "Syntax error. Expected token type {}. Got token type {}", .{
                token_type,
                self.curr().type,
            });
            diagnostics.addError(msg, self.curr().line);
            return error.SyntaxError;
        }
    }

    fn curr(self: *Parser) Token {
        return self.tokens[self.cursor];
    }

    fn peek(self: *Parser, offset: i32) Token {
        return self.tokens[@intCast(@as(i32, @intCast(self.cursor)) + offset)];
    }

    fn printCurr(self: *Parser) void {
        std.debug.print("Current token: {}\n", .{self.curr()});
    }
};

test "multi function + parameter syntax error" {
    const input =
        \\    int foo(int a, int b)
        \\{
        \\    return a + b;
        \\}
        \\
        \\int main()
        \\{
        \\    foo(1, int 1);
        \\}
        \\}
        \\
    ;

    const result = testing.cToSemanticAnalysis(input);
    try testing.expectError(error.SyntaxError, result);
}
