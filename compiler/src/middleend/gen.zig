const std = @import("std");
const c_ast = @import("../ast/c.zig");
const asm_ast = @import("../ast/asm.zig");
const diagnostics = @import("../diagnostics.zig");
const RegisterAllocator = @import("register-allocator.zig").RegisterAllocator;

pub const Generator = struct {
    allocator: std.mem.Allocator,
    program: c_ast.Program,
    instruction_buffer: std.ArrayList(asm_ast.Instruction),
    rd: asm_ast.Reg,
    rs1: asm_ast.Reg,
    rs2: asm_ast.Reg,
    immediate: i32 = 0,
    label: []const u8,
    variable_store: std.ArrayList([]const u8),
    if_counter: u32 = 0,
    short_circuit_counter: u32 = 0,
    reg_bitmap: std.bit_set.IntegerBitSet(6),
    function_line: usize = 0,

    ra: RegisterAllocator,

    pub fn init(program: c_ast.Program, allocator: std.mem.Allocator) Generator {
        return .{
            .allocator = allocator,
            .program = program,
            .instruction_buffer = std.ArrayList(asm_ast.Instruction).init(allocator),
            .rd = asm_ast.Reg.t1,
            .rs1 = asm_ast.Reg.t1,
            .rs2 = asm_ast.Reg.t1,
            .label = "",
            .variable_store = std.ArrayList([]const u8).init(allocator),
            .reg_bitmap = std.bit_set.IntegerBitSet(6).initEmpty(),
            .ra = RegisterAllocator.init(allocator),
        };
    }

    fn allocReg(self: *Generator) asm_ast.Reg {
        const allocation_order = [_]asm_ast.Reg{ .a0, .a1, .t0, .t1, .t2, .t3 };

        for (allocation_order, 0..) |reg, i| {
            if (!self.reg_bitmap.isSet(i)) {
                self.reg_bitmap.set(i);
                return reg;
            }
        }

        @panic("can't allocate more than 6 registers yet");
    }

    fn getSecondLastReg(self: *Generator) asm_ast.Reg {
        const allocation_order = [_]asm_ast.Reg{ .a0, .a1, .t0, .t1, .t2, .t3 };

        for (allocation_order, 0..) |reg, i| {
            _ = reg;
            if (!self.reg_bitmap.isSet(i) or i == allocation_order.len - 1) {
                return allocation_order[i - 2];
            }
        }

        @panic("no or 1 registers allocated");
    }

    fn getLastReg(self: *Generator) asm_ast.Reg {
        const allocation_order = [_]asm_ast.Reg{ .a0, .a1, .t0, .t1, .t2, .t3 };

        for (allocation_order, 0..) |reg, i| {
            _ = reg;
            if (!self.reg_bitmap.isSet(i) or i == allocation_order.len - 1) {
                if (i == 0) {
                    @panic("no registers allocated");
                } else {
                    return allocation_order[i - 1];
                }
            }
        }

        @panic("no registers allocated");
    }

    fn freeLastReg(self: *Generator) void {
        const allocation_order = [_]asm_ast.Reg{ .a0, .a1, .t0, .t1, .t2, .t3 };

        for (allocation_order, 0..) |reg, i| {
            _ = reg;
            if (!self.reg_bitmap.isSet(i)) {
                if (i == 0) {
                    @panic("trying to free when all registers are already free");
                } else {
                    self.reg_bitmap.unset(i - 1);
                    return;
                }
            }
        }
    }

    fn appendLabel(self: *Generator, label: []const u8) !void {
        try self.instruction_buffer.append(.{ .label = .{ .name = label } });
    }

    fn appendInstr(self: *Generator, instr: asm_ast.InstructionType) void {
        const instr_converted = asm_ast.convert(instr);
        const instruction = switch (instr_converted) {
            .rtype => asm_ast.Instruction{
                .rtype = .{
                    .instr = instr_converted.rtype,
                    .destination = self.rd,
                    .source1 = self.rs1,
                    .source2 = self.rs2,
                },
            },
            .itype => asm_ast.Instruction{
                .itype = .{
                    .instr = instr_converted.itype,
                    .destination = self.rd,
                    .source = self.rs1,
                    .immediate = self.immediate,
                },
            },
            .btype => asm_ast.Instruction{
                .btype = .{
                    .instr = instr_converted.btype,
                    .source1 = self.rs1,
                    .source2 = self.rs2,
                    .label = self.label,
                },
            },
            .stype => asm_ast.Instruction{
                .stype = .{
                    .immediate = self.immediate,
                    .instr = instr_converted.stype,
                    .source1 = self.rs1,
                    .source2 = self.rs2,
                },
            },
            .jtype => asm_ast.Instruction{
                .jtype = .{
                    .label = self.label,
                    .instr = instr_converted.jtype,
                    .destination = self.rd,
                },
            },
            else => @panic("fuck you"),
        };
        self.instruction_buffer.append(instruction) catch @panic("Failed to append instruction");
    }

    fn appendRType(self: *Generator, rtype: asm_ast.RType) !void {
        try self.instruction_buffer.append(.{ .rtype = rtype });
    }

    fn appendIType(self: *Generator, itype: asm_ast.IType) !void {
        try self.instruction_buffer.append(.{ .itype = itype });
    }

    fn appendSType(self: *Generator, stype: asm_ast.SType) !void {
        try self.instruction_buffer.append(.{ .stype = stype });
    }

    fn appendBType(self: *Generator, btype: asm_ast.BType) !void {
        try self.instruction_buffer.append(.{ .btype = btype });
    }

    fn appendJType(self: *Generator, jtype: asm_ast.JType) !void {
        try self.instruction_buffer.append(.{ .jtype = jtype });
    }

    fn loadImmediate(self: *Generator, value: i32) !asm_ast.Reg {
        const dest_reg = self.ra.getTempRegister(self.function_line);
        const unsigned_val: u32 = @bitCast(value);
        const upper_bits: u20 = @truncate(unsigned_val >> 12);
        const lower_bits: u12 = @truncate(unsigned_val);

        var add_template = asm_ast.IType{
            .instr = .ADDI,
            .destination = dest_reg,
            .source = .zero,
            .immediate = lower_bits,
        };

        if (upper_bits != 0) {
            try self.instruction_buffer.append(.{
                .utype = .{
                    .instr = .LUI,
                    .destination = dest_reg,
                    .immediate = upper_bits,
                },
            });

            add_template.source = dest_reg;
        }

        try self.instruction_buffer.append(.{ .itype = add_template });

        return dest_reg;
    }

    fn appendOperator(self: *Generator, operator: c_ast.BinaryOperator, left: asm_ast.Reg, right: asm_ast.Reg) !void {
        var template = asm_ast.RType{
            .instr = .ADD,
            .destination = left,
            .source1 = left,
            .source2 = right,
        };

        switch (operator) {
            .Add => {
                try self.appendRType(template);
            },
            .Subtract => {
                template.instr = .SUB;
                try self.appendRType(template);
            },
            .Multiply => {
                template.instr = .MUL;
                try self.appendRType(template);
            },
            .Divide => {
                template.instr = .DIV;
                try self.appendRType(template);
            },
            .Remainder => {
                template.instr = .REM;
                try self.appendRType(template);
            },
            .Bitwise_AND => {
                template.instr = .AND;
                try self.appendRType(template);
            },
            .Bitwise_OR => {
                template.instr = .OR;
                try self.appendRType(template);
            },
            .Bitwise_XOR => {
                template.instr = .XOR;
                try self.appendRType(template);
            },
            .Left_Shift => {
                template.instr = .SLL;
                try self.appendRType(template);
            },
            .Right_Shift => {
                template.instr = .SRL;
                try self.appendRType(template);
            },
            .Less => {
                template.instr = .SLT;
                try self.appendRType(template);
            },
            .Less_Or_Equal => {
                template.instr = .SLT;
                template.source1 = right;
                template.source2 = left;
                try self.appendRType(template);
                try self.appendIType(asm_ast.IType{ .immediate = 1, .source = left, .instr = .XORI, .destination = left });
            },
            .Greater => {
                template.source1 = right;
                template.source2 = left;
                template.instr = .SLT;
                try self.appendRType(template);
            },
            .Greater_Or_Equal => {
                template.instr = .SLT;
                try self.appendRType(template);
                try self.appendIType(asm_ast.IType{ .immediate = 1, .source = left, .instr = .XORI, .destination = left });
            },
            .Equal => {
                template.instr = .SUB;
                try self.appendRType(template);
                try self.appendIType(asm_ast.IType{ .immediate = 1, .source = left, .instr = .SLTIU, .destination = left });
            },
            .Not_Equal => {
                var itype_template = asm_ast.IType{ .immediate = 1, .source = left, .instr = .SLTIU, .destination = left };
                template.instr = .SUB;
                try self.appendRType(template);
                try self.appendIType(itype_template);
                itype_template.instr = .XORI;
                try self.appendIType(itype_template);
            },
            .And, .Or => @panic("And and Or operators ran in appendOperator even though they have a separate function for generation. This shouldn't happen this is a bug"),
        }
    }

    fn getVariableId(self: *Generator, identifier: []const u8) !i32 {
        var variable: ?i32 = null;
        for (self.variable_store.items, 0..) |item, index| {
            if (std.mem.eql(u8, item, identifier)) {
                variable = @intCast(index);
            }
        }

        if (variable == null) {
            try self.variable_store.append(identifier);
            variable = @as(i32, @intCast(self.variable_store.items.len)) - 1;
        }

        return variable.?;
    }

    fn generateShortCircuitingBinary(self: *Generator, binary: c_ast.Binary, label_name: []const u8, is_and: bool) !asm_ast.Reg {
        const is_short_circuit = binary.operator.getType() == .SHORT_CIRCUIT;
        if (is_short_circuit == true) {
            const source = try self.generateShortCircuitingBinary(binary.left.*.binary, label_name, binary.operator == .And);
            try self.appendBType(asm_ast.BType{ .instr = if (is_and) .BEQ else .BNE, .label = label_name, .source1 = source, .source2 = .zero });
            self.ra.expireRegister(source);
        } else {
            _ = try self.generateExpression(binary.left.*);
        }

        return try self.generateExpression(binary.right.*);
    }

    fn generateBinary(self: *Generator, binary: c_ast.Binary) !asm_ast.Reg {
        const optype = binary.operator.getType();

        if (optype == .SHORT_CIRCUIT) {
            if (binary.left.binary.operator.getType() == .SHORT_CIRCUIT or
                (binary.left.* == .binary and binary.right.* == .binary and
                binary.left.binary.operator.getType() == .COMPARISON and
                binary.right.binary.operator.getType() == .COMPARISON))
            {
                var label_name_list = std.ArrayList(u8).init(self.allocator);
                try label_name_list.appendSlice("short_circuit_end_");
                try std.fmt.format(label_name_list.writer(), "{d}", .{self.short_circuit_counter});
                self.short_circuit_counter += 1;
                const label_name = try label_name_list.toOwnedSlice();

                const dest = try self.generateShortCircuitingBinary(binary, label_name, binary.operator == .And);

                try self.appendLabel(label_name);

                return dest;
            } else {
                @panic("Can't short-circuit non comparison operators");
            }
        } else {
            // check if right side expression is a constant. if it is, evaluate left side first (non constant)
            // all expressions return a0. a1 is used for internal calculations. in other words, all right side expressions return a0, and left side return a1
            const right_is_const = binary.right.* == .constant;
            var left: ?asm_ast.Reg = null;
            if (right_is_const) {
                left = try self.generateExpression(binary.left.*);
            }

            const right = try self.generateExpression(binary.right.*);

            if (!right_is_const) {
                left = try self.generateExpression(binary.left.*);
            }

            try self.appendOperator(binary.operator, left.?, right);

            self.ra.expireRegister(right);
            return left.?;
        }
    }

    fn generateExpression(self: *Generator, exp: c_ast.Expression) anyerror!asm_ast.Reg {
        switch (exp) {
            .assignment => |assignment| {
                _ = try self.generateExpression(assignment.right.*);
                _ = try self.loadImmediate(try self.getVariableId(assignment.left.*.variable.identifier));

                try self.appendSType(asm_ast.SType{ .immediate = 0, .source1 = self.getSecondLastReg(), .source2 = self.getLastReg(), .instr = .SW });
                self.freeLastReg();
            },
            .variable => |variable| {
                _ = try self.loadImmediate(try self.getVariableId(variable.identifier));

                try self.appendIType(asm_ast.IType{ .destination = self.getLastReg(), .immediate = 0, .instr = .LW, .source = self.getLastReg() });
            },
            .constant => |constant| {
                return try self.loadImmediate(constant);
            },
            .binary => |binary| {
                return try self.generateBinary(binary);
            },
            .function_call => |function_call| {
                var arg_counter: usize = 0;
                for (function_call.args) |arg| {
                    _ = try self.generateExpression(arg.*);
                    self.rs1 = .t1;
                    self.rs2 = .zero;
                    // scuffed as shit. please remove this asap i beg you
                    switch (arg_counter) {
                        0 => self.rd = .a0,
                        1 => self.rd = .a1,
                        2 => self.rd = .a2,
                        3 => self.rd = .a3,
                        4 => self.rd = .a4,
                        5 => self.rd = .a5,
                        6 => self.rd = .a6,
                        7 => self.rd = .a7,
                        else => diagnostics.addError("Having more than 8 function arguments not supported yet", 0),
                    }
                    self.appendInstr(.ADD);
                    arg_counter += 1;
                }

                self.label = function_call.identifier;
                self.rd = .ra;
                self.appendInstr(.JAL);

                self.rs1 = .a0;
                self.rs2 = .zero;
                self.rd = .t1;
                self.appendInstr(.ADD);
            },
        }

        @panic("not implemented yet");
    }

    fn generateIf(self: *Generator, if_: c_ast.If) !void {
        var if_name_array = std.ArrayList(u8).init(self.allocator);
        defer if_name_array.deinit();
        try std.fmt.format(if_name_array.writer(), "if_end_{d}", .{self.if_counter});
        const if_name = try if_name_array.toOwnedSlice();
        var else_name_array = std.ArrayList(u8).init(self.allocator);
        defer else_name_array.deinit();
        try std.fmt.format(else_name_array.writer(), "else_end_{d}", .{self.if_counter});
        const else_name = try else_name_array.toOwnedSlice();
        self.if_counter += 1;

        _ = try self.generateExpression(if_.condition);

        try self.appendBType(asm_ast.BType{ .instr = .BEQ, .label = if_name, .source1 = .zero, .source2 = self.getLastReg() });
        self.freeLastReg();

        try self.generateStatement(if_.then.*);
        if (if_.else_ != null) {
            try self.appendJType(asm_ast.JType{ .destination = self.getLastReg(), .instr = .JAL, .label = else_name });
        }
        self.freeLastReg();

        try self.appendLabel(if_name);

        if (if_.else_ != null) {
            try self.generateStatement(if_.else_.?.*);

            try self.appendLabel(else_name);
        }
    }

    fn generateStatement(self: *Generator, statement: c_ast.Statement) anyerror!void {
        switch (statement) {
            .ret => |ret| {
                _ = try self.generateExpression(ret.exp);
            },
            .exp => |exp| {
                _ = try self.generateExpression(exp);
            },
            .if_ => |if_| {
                try self.generateIf(if_);
            },
            .compound => |compound| {
                for (compound.block_items) |block_item| {
                    switch (block_item) {
                        .statement => {
                            try self.generateStatement(block_item.statement);
                        },
                        .declaration => {
                            try self.generateDeclaration(block_item.declaration);
                        },
                    }
                }
            },
            .break_ => |break_| {
                const identifier = try std.fmt.allocPrint(self.allocator, "break_{s}", .{break_.identifier.?});

                try self.appendJType(asm_ast.JType{ .label = identifier, .destination = .zero, .instr = .JAL });
            },
            .continue_ => |continue_| {
                const identifier = try std.fmt.allocPrint(self.allocator, "continue_{s}", .{continue_.identifier.?});

                try self.appendJType(asm_ast.JType{ .label = identifier, .destination = .zero, .instr = .JAL });
            },
            .do_while => |do_while| {
                const identifier_start = try std.fmt.allocPrint(self.allocator, "{s}_start", .{do_while.identifier.?});
                const identifier_continue = try std.fmt.allocPrint(self.allocator, "continue_{s}", .{do_while.identifier.?});
                const identifier_break = try std.fmt.allocPrint(self.allocator, "break_{s}", .{do_while.identifier.?});
                try self.appendLabel(identifier_start);

                try self.generateStatement(do_while.body.*);
                try self.appendLabel(identifier_continue);

                _ = try self.generateExpression(do_while.condition);

                try self.appendBType(asm_ast.BType{ .instr = .BNE, .label = identifier_start, .source1 = self.getLastReg(), .source2 = .zero });

                try self.appendLabel(identifier_break);
            },
            .for_ => |for_| {
                const identifier_start = try std.fmt.allocPrint(self.allocator, "{s}_start", .{for_.identifier.?});
                const identifier_continue = try std.fmt.allocPrint(self.allocator, "continue_{s}", .{for_.identifier.?});
                const identifier_break = try std.fmt.allocPrint(self.allocator, "break_{s}", .{for_.identifier.?});

                switch (for_.init) {
                    .init_decl => try self.generateDeclaration(.{ .variable_declaration = for_.init.init_decl }),
                    .init_exp => if (for_.init.init_exp != null) {
                        _ = try self.generateExpression(for_.init.init_exp.?);
                    },
                }
                try self.appendLabel(identifier_start);

                if (for_.condition != null) _ = try self.generateExpression(for_.condition.?);

                try self.appendBType(asm_ast.BType{ .instr = .BEQ, .label = identifier_break, .source1 = self.getLastReg(), .source2 = .zero });
                self.freeLastReg();

                try self.generateStatement(for_.body.*);
                self.freeLastReg();

                try self.appendLabel(identifier_continue);

                if (for_.post != null) _ = try self.generateExpression(for_.post.?);

                try self.appendJType(asm_ast.JType{ .label = identifier_start, .destination = .zero, .instr = .JAL });
                try self.appendLabel(identifier_break);
                self.freeLastReg();
            },
            .while_ => |while_| {
                const identifier_continue = try std.fmt.allocPrint(self.allocator, "continue_{s}", .{while_.identifier.?});
                const identifier_break = try std.fmt.allocPrint(self.allocator, "break_{s}", .{while_.identifier.?});
                try self.appendLabel(identifier_continue);

                _ = try self.generateExpression(while_.condition);

                try self.appendBType(asm_ast.BType{ .instr = .BEQ, .label = identifier_break, .source1 = self.getLastReg(), .source2 = .zero });

                try self.generateStatement(while_.body.*);

                try self.appendJType(asm_ast.JType{ .destination = .zero, .instr = .JAL, .label = identifier_continue });

                try self.appendLabel(identifier_break);
            },
        }
    }

    fn generateDeclaration(self: *Generator, declaration: c_ast.Declaration) !void {
        switch (declaration) {
            .variable_declaration => {
                if (declaration.variable_declaration.initial == null) return else {
                    _ = try self.generateExpression(declaration.variable_declaration.initial.?);
                    _ = try self.loadImmediate(try self.getVariableId(declaration.variable_declaration.identifier));

                    try self.appendSType(asm_ast.SType{ .immediate = 0, .source1 = self.getSecondLastReg(), .source2 = self.getLastReg(), .instr = .SW });
                    self.freeLastReg();
                    self.freeLastReg();
                }
            },
            else => {},
        }
    }

    fn generateBlock(self: *Generator, block: c_ast.Block) !void {
        for (block.block_items) |block_item| {
            switch (block_item) {
                .statement => {
                    try self.generateStatement(block_item.statement);
                },
                .declaration => {
                    try self.generateDeclaration(block_item.declaration);
                },
            }
            self.function_line += 1;
        }
    }

    fn generateFunction(self: *Generator, function: c_ast.FunctionDeclaration) !void {
        try self.ra.scanFunction(function);
        self.function_line = 0;

        if (std.mem.eql(u8, function.identifier, "main")) {
            try self.appendLabel("_start");
        } else {
            try self.appendLabel(function.identifier);
        }

        try self.appendIType(asm_ast.IType{ .destination = .sp, .source = .sp, .immediate = -1, .instr = .ADDI });
        try self.appendSType(asm_ast.SType{ .instr = .SW, .source1 = .ra, .immediate = 0, .source2 = .sp });

        if (function.body != null) try self.generateBlock(function.body.?);

        try self.appendIType(asm_ast.IType{ .instr = .LW, .destination = .ra, .source = .sp, .immediate = 0 });
        try self.appendIType(asm_ast.IType{ .destination = .sp, .source = .sp, .immediate = 1, .instr = .ADDI });

        if (!std.mem.eql(u8, function.identifier, "main")) {
            self.rs1 = .ra;
            self.rd = .zero;
            self.immediate = 0;
            self.appendInstr(.JALR);
        }
    }

    pub fn generate(self: *Generator) !asm_ast.Program {
        for (self.program.function) |function| {
            try self.generateFunction(function);
        }

        return .{
            .function = .{
                .identifier = self.program.function[0].identifier,
                .instructions = try self.instruction_buffer.toOwnedSlice(),
            },
        };
    }
};
