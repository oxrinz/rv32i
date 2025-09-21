const std = @import("std");
const c_ast = @import("../../ast/c.zig");

pub const LoopLabeling = struct {
    allocator: std.mem.Allocator,
    counter: usize,

    pub fn init(allocator: std.mem.Allocator) LoopLabeling {
        return .{
            .allocator = allocator,
            .counter = 0,
        };
    }

    pub fn label(self: *LoopLabeling, program: c_ast.Program) !c_ast.Program {
        var result = program;
        self.labelFunction(&result.function[0], null);
        return result;
    }

    fn getNextId(self: *LoopLabeling) []const u8 {
        const id = std.fmt.allocPrint(self.allocator, "loop_{d}", .{self.counter}) catch unreachable;
        self.counter += 1;
        return id;
    }

    fn labelFunction(self: *LoopLabeling, function: *c_ast.FunctionDeclaration, loop_ctx: ?[]const u8) void {
        for (function.body.?.block_items) |*item| {
            self.labelBlockItem(item, loop_ctx);
        }
    }

    fn labelBlockItem(self: *LoopLabeling, item: *c_ast.BlockItem, loop_ctx: ?[]const u8) void {
        switch (item.*) {
            .statement => |*stmt| self.labelStatement(stmt, loop_ctx),
            .declaration => {},
        }
    }

    fn labelStatement(self: *LoopLabeling, stmt: *c_ast.Statement, loop_ctx: ?[]const u8) void {
        switch (stmt.*) {
            .compound => |*block| {
                for (block.block_items) |*item| {
                    self.labelBlockItem(item, loop_ctx);
                }
            },
            .if_ => |*if_stmt| {
                self.labelStatement(if_stmt.then, loop_ctx);
                if (if_stmt.else_) |else_stmt| {
                    self.labelStatement(else_stmt, loop_ctx);
                }
            },
            .while_ => |*while_stmt| {
                const label_id = self.getNextId();
                while_stmt.identifier = label_id;
                self.labelStatement(while_stmt.body, label_id);
            },
            .do_while => |*do_while_stmt| {
                const label_id = self.getNextId();
                do_while_stmt.identifier = label_id;
                self.labelStatement(do_while_stmt.body, label_id);
            },
            .for_ => |*for_stmt| {
                const label_id = self.getNextId();
                for_stmt.identifier = label_id;
                self.labelStatement(for_stmt.body, label_id);
            },
            .break_ => |*break_stmt| {
                if (loop_ctx) |ctx| {
                    break_stmt.identifier = ctx;
                }
            },
            .continue_ => |*continue_stmt| {
                if (loop_ctx) |ctx| {
                    continue_stmt.identifier = ctx;
                }
            },
            else => {},
        }
    }
};
