const std = @import("std");
const c_ast = @import("../ast/c.zig");
const asm_ast = @import("../ast/asm.zig");

const Interval = struct {
    start: usize,
    end: usize,
};

const Register = struct {
    reg: asm_ast.Reg,
    assigned: bool = false,
    variable: ?[]const u8 = null,
    expiration: ?usize = null,
};

pub const RegisterAllocator = struct {
    allocator: std.mem.Allocator,
    intervals: std.StringHashMap(Interval),
    line: usize = 0,
    registers: [5]Register,

    pub fn init(allocator: std.mem.Allocator) RegisterAllocator {
        return RegisterAllocator{
            .allocator = allocator,
            .intervals = std.StringHashMap(Interval).init(allocator),
            .registers = [_]Register{
                .{ .reg = .a0 },
                .{ .reg = .a1 },
                .{ .reg = .t0 },
                .{ .reg = .t1 },
                .{ .reg = .t2 },
            },
        };
    }

    pub fn getVariableRegister(self: *RegisterAllocator, variable: []const u8, line: usize) asm_ast.Reg {
        self.updateRegisters(line);

        for (&self.registers) |*reg| {
            if (reg.assigned and reg.variable != null) {
                if (std.mem.eql(u8, reg.variable.?, variable)) {
                    return reg.reg;
                }
            }
        }

        if (self.intervals.get(variable)) |interval| {
            for (self.registers) |*reg| {
                if (reg.assigned == false) {
                    reg.assigned = true;
                    reg.variable = variable;
                    reg.expiration = interval.end;
                    return reg.reg;
                }
            }
        }

        @panic("no registers available");
    }

    pub fn getTempRegister(self: *RegisterAllocator, line: usize) asm_ast.Reg {
        self.updateRegisters(line);

        for (&self.registers) |*reg| {
            if (!reg.assigned) {
                reg.assigned = true;
                reg.variable = null;
                reg.expiration = line + 1;
                return reg.reg;
            }
        }

        @panic("no registers available");
    }

    pub fn expireRegister(self: *RegisterAllocator, reg: asm_ast.Reg) void {
        for (&self.registers) |*self_reg| {
            if (self_reg.*.reg == reg) {
                self_reg.assigned = false;
                self_reg.variable = null;
                self_reg.expiration = null;
            }
        }
    }

    fn updateRegisters(self: *RegisterAllocator, line: usize) void {
        for (&self.registers) |*reg| {
            if (reg.assigned and reg.expiration != null and reg.expiration.? <= line) {
                reg.assigned = false;
                reg.variable = null;
                reg.expiration = null;
            }
        }
    }

    pub fn scanFunction(self: *RegisterAllocator, function: c_ast.FunctionDeclaration) !void {
        if (function.body == null) @panic("performing linear scan on a function without a body");

        self.intervals = std.StringHashMap(Interval).init(self.allocator);

        for (function.params) |param| {
            try self.intervals.put(param, .{
                .start = 0,
                .end = 0,
            });
        }

        for (function.body.?.block_items) |block_item| {
            switch (block_item) {
                .statement => |statement| {
                    try self.scanStatement(statement);
                },
                .declaration => {
                    try self.scanDeclaration(block_item.declaration);
                },
            }

            self.line += 1;
        }
    }

    fn scanVariable(self: *RegisterAllocator, variable: []const u8) !void {
        if (self.intervals.getPtr(variable)) |interval| {
            interval.end = self.line;
        } else {
            try self.intervals.put(variable, Interval{
                .start = self.line,
                .end = self.line,
            });
        }
    }

    fn scanStatement(self: *RegisterAllocator, statement: c_ast.Statement) !void {
        switch (statement) {
            .ret => |ret| {
                _ = ret;
            },
            .exp => |exp| {
                try self.scanExpression(exp);
            },
            .if_ => |if_| {
                if (if_.else_) |else_| try self.scanStatement(else_.*);
                try self.scanExpression(if_.condition);
                try self.scanStatement(if_.then.*);
            },
            .compound => |compound| {
                for (compound.block_items) |block_item| {
                    switch (block_item) {
                        .statement => {
                            try self.scanStatement(block_item.statement);
                        },
                        .declaration => {
                            try self.scanDeclaration(block_item.declaration);
                        },
                    }
                }
            },
            .do_while => |do_while| {
                try self.scanStatement(do_while.body.*);
                try self.scanExpression(do_while.condition);
            },
            .for_ => |for_| {
                if (for_.condition) |condition| try self.scanExpression(condition);
                if (for_.post) |post| try self.scanExpression(post);
                try self.scanStatement(for_.body.*);
                if (for_.init.init_exp) |init_exp| try self.scanExpression(init_exp);
                try self.scanVariable(for_.init.init_decl.identifier);
            },
            .while_ => |while_| {
                _ = while_;
            },
            else => {},
        }
    }

    fn scanDeclaration(self: *RegisterAllocator, declaration: c_ast.Declaration) !void {
        switch (declaration) {
            .variable_declaration => |variable_declaration| {
                try self.scanVariable(variable_declaration.identifier);
                if (variable_declaration.initial) |initial| try self.scanExpression(initial);
            },
            else => {},
        }
    }

    fn scanExpression(self: *RegisterAllocator, exp: c_ast.Expression) anyerror!void {
        switch (exp) {
            .assignment => |assignment| {
                try self.scanExpression(assignment.left.*);
                try self.scanExpression(assignment.right.*);
            },
            .variable => |variable| {
                try self.scanVariable(variable.identifier);
            },
            .binary => |binary| {
                try self.scanExpression(binary.left.*);
                try self.scanExpression(binary.right.*);
            },
            .function_call => |function_call| {
                for (function_call.args) |arg| {
                    try self.scanExpression(arg.*);
                }
            },
            else => {},
        }
    }
};
