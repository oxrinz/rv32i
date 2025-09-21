const std = @import("std");
const c_ast = @import("../../ast/c.zig");
const diagnostics = @import("../../diagnostics.zig");

const Symbol = struct { defined: ?bool, type_: Type };

const Type = union(enum) {
    int,
    function: Function,
};

const Function = struct {
    length: usize,
};

pub const TypeChecking = struct {
    allocator: std.mem.Allocator,
    symbols: std.StringHashMap(Symbol),

    pub fn init(allocator: std.mem.Allocator) TypeChecking {
        return .{
            .allocator = allocator,
            .symbols = std.StringHashMap(Symbol).init(allocator),
        };
    }

    pub fn check(self: *TypeChecking, program: c_ast.Program) !c_ast.Program {
        for (program.function) |function| {
            _ = try self.checkFunctionDeclaration(function);
        }
        return program;
    }

    fn checkFunctionDeclaration(self: *TypeChecking, function: c_ast.FunctionDeclaration) !c_ast.FunctionDeclaration {
        const type_ = Function{ .length = function.params.len };
        const has_body = function.body != null;

        var already_defined = false;

        if (self.symbols.get(function.identifier)) |symbol| {
            const old_function = symbol;

            switch (old_function.type_) {
                .function => {
                    if (!std.mem.eql(u8, std.mem.asBytes(&type_), std.mem.asBytes(&old_function.type_.function))) {
                        const msg = try std.fmt.allocPrint(diagnostics.arena.allocator(), "Incompatible declarations for function {s}", .{function.identifier});
                        diagnostics.addError(msg, null);
                        return error.IncompatibleFunctionDeclarations;
                    }
                },
                else => {
                    const msg = try std.fmt.allocPrint(diagnostics.arena.allocator(), "Incompatible declarations for function {s}", .{function.identifier});
                    diagnostics.addError(msg, null);
                    return error.IncompatibleFunctionDeclarations;
                },
            }

            already_defined = old_function.defined.?;

            if (already_defined and has_body) {
                const msg = try std.fmt.allocPrint(diagnostics.arena.allocator(), "Function already defined {s}", .{function.identifier});
                diagnostics.addError(msg, null);
                return error.FunctionAlreadyDefined;
            }
        }

        try self.symbols.put(function.identifier, Symbol{
            .type_ = .{
                .function = type_,
            },
            .defined = already_defined or has_body,
        });

        if (has_body) {
            for (function.params) |param| {
                try self.symbols.put(param, Symbol{
                    .type_ = .int,
                    .defined = null,
                });
            }

            _ = try self.checkBlock(function.body.?);
        }

        return function;
    }

    fn checkVariableDeclaration(self: *TypeChecking, variable: c_ast.VariableDeclaration) !c_ast.VariableDeclaration {
        try self.symbols.put(
            variable.identifier,
            .{
                .type_ = .int,
                .defined = null,
            },
        );

        if (variable.initial != null) {
            _ = try self.checkExpression(variable.initial.?);
        }

        return variable;
    }

    fn checkBlock(self: *TypeChecking, block: c_ast.Block) anyerror!c_ast.Block {
        const result = block;

        for (block.block_items) |block_item| {
            switch (block_item) {
                .declaration => |decl| {
                    _ = try self.checkDeclaration(decl);
                },
                .statement => |stmt| {
                    _ = try self.checkStatement(stmt);
                },
            }
        }

        return result;
    }

    fn checkDeclaration(self: *TypeChecking, declaration: c_ast.Declaration) anyerror!c_ast.Declaration {
        var result = declaration;
        switch (declaration) {
            .function_declaration => |func_decl| result.function_declaration = try self.checkFunctionDeclaration(func_decl),
            .variable_declaration => |var_decl| result.variable_declaration = try self.checkVariableDeclaration(var_decl),
        }
        return result;
    }

    fn checkStatement(self: *TypeChecking, statement: c_ast.Statement) !c_ast.Statement {
        switch (statement) {
            .compound => |compound| {
                _ = try self.checkBlock(compound);
            },
            .do_while => |do_while| {
                _ = try self.checkExpression(do_while.condition);
                _ = try self.checkStatement(do_while.body.*);
            },
            .exp => |exp| {
                _ = try self.checkExpression(exp);
            },
            .for_ => |for_| {
                _ = try self.checkStatement(for_.body.*);
                if (for_.condition != null) _ = try self.checkExpression(for_.condition.?);
                if (for_.post != null) _ = try self.checkExpression(for_.post.?);
                switch (for_.init) {
                    .init_decl => _ = try self.checkVariableDeclaration(for_.init.init_decl),
                    .init_exp => {
                        if (for_.init.init_exp != null) _ = try self.checkExpression(for_.init.init_exp.?);
                    },
                }
            },
            .if_ => |if_| {
                _ = try self.checkExpression(if_.condition);
                _ = try self.checkStatement(if_.then.*);
                if (if_.else_ != null) _ = try self.checkStatement(if_.else_.?.*);
            },
            .ret => |ret| {
                _ = try self.checkExpression(ret.exp);
            },
            .while_ => |while_| {
                _ = try self.checkExpression(while_.condition);
                _ = try self.checkStatement(while_.body.*);
            },
            else => {}, //nothing to check
        }

        return statement;
    }

    fn checkExpression(self: *TypeChecking, expression: c_ast.Expression) !c_ast.Expression {
        switch (expression) {
            .variable => {
                if (self.symbols.get(expression.variable.identifier).?.type_ != .int) {
                    const msg = try std.fmt.allocPrint(diagnostics.arena.allocator(), "Function name {s} used as a variable", .{expression.variable.identifier});
                    diagnostics.addError(msg, null);
                    return error.FunctionUsedAsVariable;
                }
            },
            .function_call => {
                const type_ = self.symbols.get(expression.function_call.identifier).?.type_;

                if (type_ == .int) {
                    const msg = try std.fmt.allocPrint(diagnostics.arena.allocator(), "Variable {s} used as function name", .{expression.function_call.identifier});
                    diagnostics.addError(msg, null);
                    return error.VariableUsedAsFunction;
                }
                if (type_.function.length != expression.function_call.args.len) {
                    const msg = try std.fmt.allocPrint(diagnostics.arena.allocator(), "Function {s} called with wrong number of arguments", .{expression.function_call.identifier});
                    diagnostics.addError(msg, null);
                    return error.FunctionCallWrongArguments;
                }
                for (expression.function_call.args) |arg| {
                    _ = try self.checkExpression(arg.*);
                }
            },
            else => {},
        }

        return expression;
    }
};
