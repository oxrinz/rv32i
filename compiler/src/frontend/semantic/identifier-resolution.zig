const std = @import("std");
const c_ast = @import("../../ast/c.zig");
const diagnostics = @import("../../diagnostics.zig");

const MapEntry = struct {
    new_name: []const u8,
    from_current_scope: bool,
    has_linkage: bool,
};

pub const IdentifierResolution = struct {
    allocator: std.mem.Allocator,
    counter: usize,

    pub fn init(allocator: std.mem.Allocator) IdentifierResolution {
        return .{
            .allocator = allocator,
            .counter = 0,
        };
    }

    pub fn resolve(self: *IdentifierResolution, program: c_ast.Program) !c_ast.Program {
        var identifier_map = std.StringHashMap(MapEntry).init(self.allocator);

        var new_program = program;
        new_program = new_program;

        for (new_program.function) |*function| {
            function.* = try self.resolveFunctionDeclaration(function.*, &identifier_map);
        }

        return new_program;
    }

    fn resolveBlock(self: *IdentifierResolution, block: c_ast.Block, identifier_map: *std.StringHashMap(MapEntry)) anyerror!c_ast.Block {
        var new_block = block;
        new_block = new_block; // dig doesn't recognize that editing arrays with a pointer modifies an object, in this case new_block
        for (new_block.block_items) |*block_item| {
            switch (block_item.*) {
                .declaration => {
                    block_item.declaration = try self.resolveDeclaration(block_item.declaration, identifier_map);
                },
                .statement => {
                    block_item.statement = try self.resolveStatement(block_item.statement, identifier_map);
                },
            }
        }
        return new_block;
    }

    // resolves local variables and parameters. didn't name it properly to avoid long name
    fn resolveLocal(self: *IdentifierResolution, identifier: []const u8, identifier_map: *std.StringHashMap(MapEntry)) !MapEntry {
        if (identifier_map.get(identifier)) |entry| {
            if (entry.from_current_scope) {
                const err_msg = try std.fmt.allocPrint(self.allocator, "Duplicate identifier definition: {s}", .{identifier});
                diagnostics.addError(err_msg, null);
                return error.DuplicateDefinition;
            }
        }

        const unique_name = try std.fmt.allocPrint(self.allocator, "var_{d}", .{self.counter});
        self.counter += 1;

        return MapEntry{
            .from_current_scope = true,
            .new_name = unique_name,
            .has_linkage = true,
        };
    }

    fn resolveVariableDeclaration(self: *IdentifierResolution, declaration: c_ast.VariableDeclaration, identifier_map: *std.StringHashMap(MapEntry)) !c_ast.VariableDeclaration {
        var result = declaration;

        const entry = try self.resolveLocal(result.identifier, identifier_map);

        try identifier_map.put(
            result.identifier,
            entry,
        );

        result.identifier = entry.new_name;

        if (result.initial != null) {
            result.initial = try self.resolveExp(result.initial.?, identifier_map);
        }

        return result;
    }

    fn resolveFunctionDeclaration(self: *IdentifierResolution, declaration: c_ast.FunctionDeclaration, identifier_map: *std.StringHashMap(MapEntry)) !c_ast.FunctionDeclaration {
        var result = declaration;

        if (identifier_map.get(result.identifier)) |entry| {
            if (entry.from_current_scope == true and entry.has_linkage == false) @panic("Duplicate declaration");
        }

        try identifier_map.put(
            result.identifier,
            MapEntry{
                .from_current_scope = true,
                .new_name = result.identifier,
                .has_linkage = true,
            },
        );

        var inner_map = try self.cloneVariableMap(identifier_map);
        var new_params = std.ArrayList([]const u8).init(self.allocator);
        for (result.params) |param| {
            const entry = try self.resolveLocal(param, &inner_map);
            try new_params.append(entry.new_name);
            try inner_map.put(param, entry);
        }
        result.params = try new_params.toOwnedSlice();

        if (result.body != null) {
            result.body = try self.resolveBlock(result.body.?, &inner_map);
        }

        return result;
    }

    fn resolveDeclaration(self: *IdentifierResolution, declaration: c_ast.Declaration, identifier_map: *std.StringHashMap(MapEntry)) !c_ast.Declaration {
        switch (declaration) {
            .variable_declaration => {
                return .{ .variable_declaration = try self.resolveVariableDeclaration(declaration.variable_declaration, identifier_map) };
            },
            else => {
                return .{ .function_declaration = try self.resolveFunctionDeclaration(declaration.function_declaration, identifier_map) };
            },
        }
    }

    fn cloneVariableMap(self: *IdentifierResolution, identifier_map: *std.StringHashMap(MapEntry)) !std.StringHashMap(MapEntry) {
        _ = self;
        var new_map = std.StringHashMap(MapEntry).init(identifier_map.allocator);

        var iterator = identifier_map.iterator();
        while (iterator.next()) |entry| {
            var new_entry = entry.value_ptr.*;
            new_entry.from_current_scope = false;
            try new_map.put(entry.key_ptr.*, new_entry);
        }

        return new_map;
    }

    fn resolveStatement(self: *IdentifierResolution, statement: c_ast.Statement, identifier_map: *std.StringHashMap(MapEntry)) !c_ast.Statement {
        var result = statement;
        switch (result) {
            .exp => {
                result.exp = try self.resolveExp(result.exp, identifier_map);
            },
            .ret => {
                result.ret.exp = try self.resolveExp(result.ret.exp, identifier_map);
            },
            .if_ => {
                var else_: ?*c_ast.Statement = null;
                if (result.if_.else_ != null) {
                    const resolved_else = try self.resolveStatement(result.if_.else_.?.*, identifier_map);
                    else_ = try self.allocator.create(c_ast.Statement);
                    else_.?.* = resolved_else;
                }

                const resolved_then = try self.resolveStatement(result.if_.then.*, identifier_map);
                const then_statement = try self.allocator.create(c_ast.Statement);
                then_statement.* = resolved_then;

                result.if_ = .{
                    .condition = try self.resolveExp(result.if_.condition, identifier_map),
                    .then = then_statement,
                    .else_ = else_,
                };
            },
            .compound => {
                var new_map = try self.cloneVariableMap(identifier_map);
                result.compound = try self.resolveBlock(result.compound, &new_map);
            },
            .break_ => {},
            .continue_ => {},
            .do_while => |*do_while| {
                const body = try self.resolveStatement(do_while.*.body.*, identifier_map);
                const body_ptr = try self.allocator.create(c_ast.Statement);
                body_ptr.* = body;

                do_while.body = body_ptr;
                do_while.condition = try self.resolveExp(do_while.*.condition, identifier_map);
            },
            .for_ => |*for_| {
                switch (for_.init) {
                    .init_decl => {
                        const decl = try self.resolveDeclaration(.{ .variable_declaration = for_.init.init_decl }, identifier_map);
                        for_.init.init_decl = decl.variable_declaration;
                    },
                    .init_exp => {
                        if (for_.init.init_exp != null) {
                            for_.init.init_exp = try self.resolveExp(for_.init.init_exp.?, identifier_map);
                        }
                    },
                }

                if (for_.condition != null) {
                    for_.condition = try self.resolveExp(for_.*.condition.?, identifier_map);
                }

                if (for_.post != null) {
                    for_.post = try self.resolveExp(for_.*.post.?, identifier_map);
                }

                const body = try self.resolveStatement(for_.*.body.*, identifier_map);
                const body_ptr = try self.allocator.create(c_ast.Statement);
                body_ptr.* = body;

                for_.body = body_ptr;
            },
            .while_ => |*while_| {
                const body = try self.resolveStatement(while_.*.body.*, identifier_map);
                const body_ptr = try self.allocator.create(c_ast.Statement);
                body_ptr.* = body;

                while_.body = body_ptr;
                while_.condition = try self.resolveExp(while_.*.condition, identifier_map);
            },
        }
        return result;
    }

    fn resolveExp(self: *IdentifierResolution, expression: c_ast.Expression, identifier_map: *std.StringHashMap(MapEntry)) !c_ast.Expression {
        var result = expression;
        switch (result) {
            .variable => {
                result.variable.identifier = identifier_map.get(result.variable.identifier).?.new_name;
            },
            .binary => {
                result.binary.left.* = try self.resolveExp(result.binary.left.*, identifier_map);
                result.binary.right.* = try self.resolveExp(result.binary.right.*, identifier_map);
            },
            .assignment => {
                if (result.assignment.left.* != .variable) @panic("Invalid lvalue");
                result.assignment.left.* = try self.resolveExp(result.assignment.left.*, identifier_map);
                result.assignment.right.* = try self.resolveExp(result.assignment.right.*, identifier_map);
            },
            .constant => {},
            .function_call => {
                if (identifier_map.get(result.function_call.identifier)) |entry| {
                    const new_name = entry.new_name;
                    var new_args = std.ArrayList(*c_ast.Expression).init(self.allocator);
                    for (result.function_call.args) |arg| {
                        const expr = try self.allocator.create(c_ast.Expression);
                        expr.* = try self.resolveExp(arg.*, identifier_map);
                        try new_args.append(expr);
                    }
                    return .{
                        .function_call = .{
                            .identifier = new_name,
                            .args = try new_args.toOwnedSlice(),
                        },
                    };
                } else {
                    const err_msg = try std.fmt.allocPrint(self.allocator, "Undeclared function: {s}", .{result.function_call.identifier});
                    diagnostics.addError(err_msg, null);
                    return error.UndeclaredFunction;
                }
            },
        }
        return result;
    }
};
