const std = @import("std");
const instr_types = @import("instruction-types.zig");
const instr_getters = @import("instruction-getters.zig");

const Instruction = union(enum) {
    RType: struct {
        instruction: instr_types.RTypeInstruction,
        rd: u8,
        rs1: u8,
        rs2: u8,
    },
    IType: struct {
        instruction: instr_types.ITypeInstruction,
        rd: u8,
        rs1: u8,
        imm: i12,
    },
    SType: struct {
        instruction: instr_types.STypeInstruction,
        rs1: u8,
        rs2: u8,
        imm: i12,
    },
    BType: struct {
        instruction: instr_types.BTypeInstruction,
        rs1: u8,
        rs2: u8,
        imm: i12,
    },
    UType: struct {
        instruction: instr_types.UTypeInstruction,
        rd: u8,
        imm: i20,
    },
    JType: struct {
        instruction: instr_types.JTypeInstruction,
        rd: u8,
        imm: i20,
    },
    fn encode(self: *const Instruction) !u32 {
        return switch (self.*) {
            .RType => |rtype| {
                const opcode = 0b0110011;

                const rd = @as(u32, rtype.rd);
                const rs1 = @as(u32, rtype.rs1);
                const rs2 = @as(u32, rtype.rs2);

                const funct3: u32 = switch (rtype.instruction) {
                    .ADD, .SUB, .MUL => 0b000,
                    .XOR, .DIV => 0b100,
                    .OR, .REM => 0b110,
                    .AND, .REMU => 0b111,
                    .SLL, .MULH => 0b001,
                    .SRL, .SRA, .DIVU => 0b101,
                    .SLT, .MULSU => 0b010,
                    .SLTU, .MULU => 0b011,
                };

                const funct7: u32 = switch (rtype.instruction) {
                    .SUB, .SRA => 0b0100000,
                    .MUL, .MULH, .MULSU, .MULU, .DIV, .DIVU, .REM, .REMU => 0b0000001,
                    else => 0b0000000,
                };

                return opcode |
                    (rd << 7) |
                    (funct3 << 12) |
                    (rs1 << 15) |
                    (rs2 << 20) |
                    (funct7 << 25);
            },
            .IType => |itype| {
                const opcode: u32 = switch (itype.instruction) {
                    .LB, .LH, .LW, .LBU, .LHU => 0b0000011,
                    .JALR => 0b1100111,
                    else => 0b0010011,
                };

                const rd = @as(u32, itype.rd);
                const rs1 = @as(u32, itype.rs1);

                const imm_bits: u12 = @bitCast(itype.imm);
                const imm = switch (itype.instruction) {
                    .SLLI, .SRLI => @as(u32, imm_bits & 0x1F),
                    .SRAI => @as(u32, (imm_bits & 0x1F) | 0x400),
                    else => @as(u32, imm_bits),
                };

                const funct3: u32 = switch (itype.instruction) {
                    .ADDI => 0b000,
                    .XORI => 0b100,
                    .ORI => 0b110,
                    .ANDI => 0b111,
                    .SLLI => 0b001,
                    .SRLI, .SRAI => 0b101,
                    .SLTI => 0b010,
                    .SLTIU => 0b011,

                    .LB => 0b000,
                    .LH => 0b001,
                    .LW => 0b010,
                    .LBU => 0b100,
                    .LHU => 0b101,
                    .JALR => 0b000,
                };

                return opcode |
                    (rd << 7) |
                    (funct3 << 12) |
                    (rs1 << 15) |
                    (imm << 20);
            },
            .SType => |stype| {
                const opcode = 0b0100011;

                const rs1 = @as(u32, stype.rs1);
                const rs2 = @as(u32, stype.rs2);
                const imm_bits: u12 = @bitCast(stype.imm);

                const funct3: u32 = switch (stype.instruction) {
                    .SB => 0b000,
                    .SH => 0b001,
                    .SW => 0b010,
                };

                const imm_lo = imm_bits & 0x1F;
                const imm_hi = @as(u32, (imm_bits >> 5) & 0x7F);

                return opcode |
                    (imm_lo << 7) |
                    (funct3 << 12) |
                    (rs1 << 15) |
                    (rs2 << 20) |
                    (imm_hi << 25);
            },
            .BType => |btype| {
                const opcode = 0b1100011;

                const rs1 = @as(u32, btype.rs1);
                const rs2 = @as(u32, btype.rs2);
                const imm_bits: u12 = @bitCast(btype.imm);

                const imm_lo = imm_bits & 0x1F;
                const imm_hi = @as(u32, (imm_bits >> 5) & 0x7F);

                const funct3: u32 = switch (btype.instruction) {
                    .BEQ => 0b000,
                    .BNE => 0b001,
                    .BLT => 0b100,
                    .BGE => 0b101,
                    .BLTU => 0b110,
                    .BGEU => 0b111,
                };

                return opcode |
                    (imm_lo << 7) |
                    (funct3 << 12) |
                    (rs1 << 15) |
                    (rs2 << 20) |
                    (imm_hi << 25);
            },
            .UType => |utype| {
                const opcode: u32 = switch (utype.instruction) {
                    .LUI => 0b0110111,
                    .AUIPC => 0b0010111,
                };

                const rd = @as(u32, utype.rd);
                const imm_bits: u20 = @bitCast(utype.imm);
                const imm = @as(u32, imm_bits);

                return opcode |
                    (rd << 7) |
                    (imm << 12);
            },
            .JType => |jtype| {
                const opcode = 0b1101111;
                const rd = @as(u32, jtype.rd);

                const imm_bits: u20 = @bitCast(jtype.imm);
                const imm = @as(u32, imm_bits);

                return opcode |
                    (rd << 7) |
                    (imm << 12);
            },
        };
    }
};

fn splitStringIntoLines(allocator: *const std.mem.Allocator, input: []const u8) ![][]const u8 {
    var lines = std.ArrayList([]const u8).init(allocator.*);
    defer lines.deinit();
    var tokenizer = std.mem.tokenize(u8, input, "\n");
    while (tokenizer.next()) |line| {
        try lines.append(line);
    }
    return lines.toOwnedSlice();
}

fn splitStringByWhitespace(allocator: *const std.mem.Allocator, input: []const u8) ![][]const u8 {
    var tokens = std.ArrayList([]const u8).init(allocator.*);
    defer tokens.deinit();
    var tokenizer = std.mem.tokenize(u8, input, " \t\n\r");
    while (tokenizer.next()) |token| {
        try tokens.append(token);
    }
    return tokens.toOwnedSlice();
}

fn assemble(allocator: *const std.mem.Allocator, source: []const u8) !std.ArrayList(u32) {
    const lines = try splitStringIntoLines(allocator, source);
    defer allocator.free(lines);

    var encoded = std.ArrayList(u32).init(allocator.*);

    if (!@import("builtin").is_test) {
        const jal_str = "jal zero _start";

        const jal_tokens = try splitStringByWhitespace(allocator, jal_str);
        defer allocator.free(jal_tokens);

        var jal_instruction = try parseInstruction(allocator, jal_tokens, lines, 0);
        jal_instruction.JType.imm += 1;
        try encoded.append(try jal_instruction.encode());
    }

    for (lines, 0..) |line, index| {
        if (line.len > 0 and line[0] == ';' or line[line.len - 1] == ':') continue;

        const tokens = try splitStringByWhitespace(allocator, line);
        defer allocator.free(tokens);
        const pseudo_parsed_tokens = try parsePseudoInstruction(allocator, tokens);
        const instruction = try parseInstruction(allocator, pseudo_parsed_tokens, lines, index);
        try encoded.append(try instruction.encode());
    }

    return encoded;
}

const InstructionType = enum {
    RType,
    IType,
    SType,
    BType,
    UType,
    JType,
    None,
};

fn getInstructionType(instruction: []const u8, instruction_sets: struct {
    rtype: []const []const u8,
    itype: []const []const u8,
    stype: []const []const u8,
    btype: []const []const u8,
    utype: []const []const u8,
    jtype: []const []const u8,
}) InstructionType {
    for (instruction_sets.rtype) |candidate| {
        if (std.mem.eql(u8, instruction, candidate)) {
            return .RType;
        }
    }
    for (instruction_sets.itype) |candidate| {
        if (std.mem.eql(u8, instruction, candidate)) {
            return .IType;
        }
    }
    for (instruction_sets.stype) |candidate| {
        if (std.mem.eql(u8, instruction, candidate)) {
            return .SType;
        }
    }
    for (instruction_sets.btype) |candidate| {
        if (std.mem.eql(u8, instruction, candidate)) {
            return .BType;
        }
    }
    for (instruction_sets.utype) |candidate| {
        if (std.mem.eql(u8, instruction, candidate)) {
            return .UType;
        }
    }
    for (instruction_sets.jtype) |candidate| {
        if (std.mem.eql(u8, instruction, candidate)) {
            return .JType;
        }
    }
    return .None;
}

fn createRegMap(allocator: *const std.mem.Allocator) !std.StringHashMap(u8) {
    const reg_names = [_][]const u8{
        "zero", "ra", "sp", "gp", "tp", "t0", "t1", "t2", "s0", "s1", "a0", "a1", "a2",  "a3",
        "a4",   "a5", "a6", "a7", "s2", "s3", "s4", "s5", "s6", "s7", "s8", "s9", "s10", "s11",
        "t3",   "t4", "t5", "t6",
    };
    var map = std.StringHashMap(u8).init(allocator.*);
    for (reg_names, 0..) |name, index| {
        try map.put(name, @as(u8, @intCast(index)));
    }
    try map.put("fp", 8);
    return map;
}

fn parseRegister(reg: []const u8, reg_map: *const std.StringHashMap(u8)) !u8 {
    if (reg[0] == 'x') {
        return try std.fmt.parseInt(u8, reg[1..], 10);
    } else {
        return reg_map.get(reg).?;
    }
}

fn findLabelRelativeIndex(lines: [][]const u8, name: []const u8, index: usize) i32 {
    var found: ?usize = null;
    var buffer: [33]u8 = undefined;
    const label_name = std.fmt.bufPrint(&buffer, "{s}:", .{name}) catch unreachable;

    for (lines, 0..) |line, found_index| {
        if (std.mem.eql(u8, line[0..line.len], label_name)) {
            found = found_index;
            break;
        }
    }

    if (found == null) std.debug.panic("Label of name {s} not found", .{label_name});
    const found_index = found.?;

    var labels_encountered: usize = 0;

    if (found_index < index) {
        for (lines[found_index..index]) |line| {
            if (line.len > 0 and line[line.len - 1] == ':') {
                labels_encountered += 1;
            }
        }

        return -@as(i32, @intCast(index - found_index - labels_encountered));
    } else {
        for (lines[index..found_index]) |line| {
            if (line.len > 0 and line[line.len - 1] == ':') {
                labels_encountered += 1;
            }
        }

        return @as(i32, @intCast(found_index - index - labels_encountered));
    }
}

fn parsePseudoInstruction(allocator: *const std.mem.Allocator, tokens: [][]const u8) ![][]const u8 {
    if (tokens.len == 0) return tokens;

    const pseudo = tokens[0];

    if (std.mem.eql(u8, pseudo, "ret")) {
        var result = try allocator.alloc([]const u8, 4);
        result[0] = "jalr";
        result[1] = "x0";
        result[2] = "x1";
        result[3] = "0";
        return result;
    }

    return tokens;
}

fn parseInstruction(allocator: *const std.mem.Allocator, tokens: [][]const u8, lines: [][]const u8, index: usize) !Instruction {
    var reg_map = try createRegMap(allocator);
    defer reg_map.deinit();

    const instruction_token = tokens[0];
    const instruction_sets = .{
        .rtype = &[_][]const u8{ "add", "sub", "mul", "div", "rem", "sll", "slt", "sltu", "xor", "srl", "sra", "or", "and" },
        .itype = &[_][]const u8{ "addi", "muli", "divi", "slti", "sltiu", "xori", "andi", "ori", "slli", "srli", "srai", "lb", "lh", "lw", "lbu", "lhu", "jalr" },
        .stype = &[_][]const u8{ "sb", "sh", "sw" },
        .btype = &[_][]const u8{ "beq", "bne", "blt", "bge", "bltu", "bgeu" },
        .utype = &[_][]const u8{ "lui", "auipc" },
        .jtype = &[_][]const u8{"jal"},
    };

    var instruction: Instruction = undefined;

    switch (getInstructionType(instruction_token, instruction_sets)) {
        .RType => {
            instruction = .{ .RType = .{
                .instruction = try instr_getters.getRTypeInstruction(instruction_token),
                .rd = try parseRegister(tokens[1], &reg_map),
                .rs1 = try parseRegister(tokens[2], &reg_map),
                .rs2 = try parseRegister(tokens[3], &reg_map),
            } };
        },
        .IType => {
            const base_instruction = try instr_getters.getITypeInstruction(instruction_token);

            const load_instructions = [_][]const u8{ "lb", "lh", "lw", "lbu", "lhu" };
            const is_load = for (load_instructions) |load_instr| {
                if (std.mem.eql(u8, instruction_token, load_instr)) break true;
            } else false;

            if (is_load) {
                const rd = try parseRegister(tokens[1], &reg_map);

                const offset_reg = tokens[2];
                const paren_idx = std.mem.indexOf(u8, offset_reg, "(").?;
                const imm = try std.fmt.parseInt(i12, offset_reg[0..paren_idx], 10);

                const rs1_str = offset_reg[paren_idx + 1 .. offset_reg.len - 1];
                const rs1 = try parseRegister(rs1_str, &reg_map);

                instruction = .{ .IType = .{
                    .instruction = base_instruction,
                    .rd = rd,
                    .rs1 = rs1,
                    .imm = imm,
                } };
            } else if (std.mem.eql(u8, instruction_token, "jalr")) {
                const rd = try parseRegister(tokens[1], &reg_map);
                const rs1 = try parseRegister(tokens[2], &reg_map);
                const imm = try std.fmt.parseInt(i12, tokens[3], 10);

                instruction = .{ .IType = .{
                    .instruction = base_instruction,
                    .rd = rd,
                    .rs1 = rs1,
                    .imm = imm,
                } };
            } else {
                instruction = .{ .IType = .{
                    .instruction = base_instruction,
                    .rd = try parseRegister(tokens[1], &reg_map),
                    .rs1 = try parseRegister(tokens[2], &reg_map),
                    .imm = try std.fmt.parseInt(i12, tokens[3], 10),
                } };
            }
        },
        .SType => {
            const rs2 = try parseRegister(tokens[1], &reg_map);
            const offset_rs1 = tokens[2];
            const paren_idx = std.mem.indexOf(u8, offset_rs1, "(").?;
            const imm = try std.fmt.parseInt(i12, offset_rs1[0..paren_idx], 10);
            const rs1_str = offset_rs1[paren_idx + 1 .. offset_rs1.len - 1];
            const rs1 = try parseRegister(rs1_str, &reg_map);

            instruction = .{
                .SType = .{
                    .instruction = try instr_getters.getSTypeInstruction(instruction_token),
                    .rs1 = rs1,
                    .rs2 = rs2,
                    .imm = imm,
                },
            };
        },
        .BType => {
            const imm: i12 = @intCast(findLabelRelativeIndex(lines, tokens[3], index));

            instruction = .{
                .BType = .{
                    .instruction = try instr_getters.getBTypeInstruction(instruction_token),
                    .rs1 = try parseRegister(tokens[1], &reg_map),
                    .rs2 = try parseRegister(tokens[2], &reg_map),
                    .imm = imm,
                },
            };
        },
        .UType => {
            instruction = .{
                .UType = .{
                    .instruction = try instr_getters.getUTypeInstruction(instruction_token),
                    .rd = try parseRegister(tokens[1], &reg_map),
                    .imm = try std.fmt.parseInt(i20, tokens[2], 10),
                },
            };
        },
        .JType => {
            const imm: i20 = @intCast(findLabelRelativeIndex(lines, tokens[2], index));

            instruction = .{
                .JType = .{
                    .instruction = try instr_getters.getJTypeInstruction(instruction_token),
                    .rd = try parseRegister(tokens[1], &reg_map),
                    .imm = imm,
                },
            };
        },

        else => return error.UnknownInstruction,
    }

    return instruction;
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const args = try std.process.argsAlloc(std.heap.page_allocator);
    defer std.process.argsFree(std.heap.page_allocator, args);

    const input_path = args[1];
    const output_path = args[2];

    const file = try std.fs.cwd().openFile(input_path, .{});
    defer file.close();

    const source_code = try file.readToEndAlloc(std.heap.page_allocator, 1024 * 1024);
    defer std.heap.page_allocator.free(source_code);

    const machine_code = try assemble(&allocator, source_code);

    const output_file = try std.fs.cwd().createFile(output_path, .{
        .read = true,
        .truncate = true,
    });
    defer output_file.close();

    var buf: [4]u8 = undefined;
    for (machine_code.items) |code| {
        buf[0] = @truncate(code >> 24);
        buf[1] = @truncate(code >> 16);
        buf[2] = @truncate(code >> 8);
        buf[3] = @truncate(code);
        try output_file.writeAll(&buf);
    }
}

test "add" {
    const machine_code = try assemble(&std.testing.allocator, "add ra sp gp");
    defer machine_code.deinit();
    try std.testing.expectEqual(@as(u32, 0x3100B3), machine_code.items[0]);
}

test "sub" {
    const machine_code = try assemble(&std.testing.allocator, "sub tp t0 t1");
    defer machine_code.deinit();
    try std.testing.expectEqual(@as(u32, 0x40628233), machine_code.items[0]);
}

test "sll" {
    const machine_code = try assemble(&std.testing.allocator, "sll t2 s0 fp");
    defer machine_code.deinit();
    try std.testing.expectEqual(@as(u32, 0x8413B3), machine_code.items[0]);
}

test "slt" {
    const machine_code = try assemble(&std.testing.allocator, "slt s1 a0 a1");
    defer machine_code.deinit();
    try std.testing.expectEqual(@as(u32, 0xB524B3), machine_code.items[0]);
}

test "sltu" {
    const machine_code = try assemble(&std.testing.allocator, "sltu a2 a3 a4");
    defer machine_code.deinit();
    try std.testing.expectEqual(@as(u32, 0xE6B633), machine_code.items[0]);
}

test "xor" {
    const machine_code = try assemble(&std.testing.allocator, "xor a5 a6 a7");
    defer machine_code.deinit();
    try std.testing.expectEqual(@as(u32, 0x11847B3), machine_code.items[0]);
}

test "srl" {
    const machine_code = try assemble(&std.testing.allocator, "srl s2 s3 s4");
    defer machine_code.deinit();
    try std.testing.expectEqual(@as(u32, 0x149D933), machine_code.items[0]);
}

test "sra" {
    const machine_code = try assemble(&std.testing.allocator, "sra s5 s6 s7");
    defer machine_code.deinit();
    try std.testing.expectEqual(@as(u32, 0x417B5AB3), machine_code.items[0]);
}

test "or" {
    const machine_code = try assemble(&std.testing.allocator, "or s8 s9 s10");
    defer machine_code.deinit();
    try std.testing.expectEqual(@as(u32, 0x1ACEC33), machine_code.items[0]);
}

test "and" {
    const machine_code = try assemble(&std.testing.allocator, "and t3 t4 t5");
    defer machine_code.deinit();
    try std.testing.expectEqual(@as(u32, 0x1EEFE33), machine_code.items[0]);
}

test "addi" {
    const machine_code = try assemble(&std.testing.allocator, "addi t6 ra 3");
    defer machine_code.deinit();
    try std.testing.expectEqual(@as(u32, 0x308F93), machine_code.items[0]);
}

test "slti" {
    const machine_code = try assemble(&std.testing.allocator, "slti sp sp 3");
    defer machine_code.deinit();
    try std.testing.expectEqual(@as(u32, 0x312113), machine_code.items[0]);
}

test "sltiu" {
    const machine_code = try assemble(&std.testing.allocator, "sltiu a0 a0 3");
    defer machine_code.deinit();
    try std.testing.expectEqual(@as(u32, 0x353513), machine_code.items[0]);
}

test "xori" {
    const machine_code = try assemble(&std.testing.allocator, "xori a1 a1 3");
    defer machine_code.deinit();
    try std.testing.expectEqual(@as(u32, 0x35C593), machine_code.items[0]);
}

test "ori" {
    const machine_code = try assemble(&std.testing.allocator, "ori a2 a2 3");
    defer machine_code.deinit();
    try std.testing.expectEqual(@as(u32, 0x366613), machine_code.items[0]);
}

test "andi" {
    const machine_code = try assemble(&std.testing.allocator, "andi a3 a3 3");
    defer machine_code.deinit();
    try std.testing.expectEqual(@as(u32, 0x36F693), machine_code.items[0]);
}

test "slli" {
    const machine_code = try assemble(&std.testing.allocator, "slli a4 a4 3");
    defer machine_code.deinit();
    try std.testing.expectEqual(@as(u32, 0x371713), machine_code.items[0]);
}

test "srai" {
    const machine_code = try assemble(&std.testing.allocator, "srai a6 a6 3");
    defer machine_code.deinit();
    try std.testing.expectEqual(@as(u32, 0x40385813), machine_code.items[0]);
}

test "lb" {
    const machine_code = try assemble(&std.testing.allocator, "lb x19 24(x20)");
    defer machine_code.deinit();
    try std.testing.expectEqual(@as(u32, 0x018A0983), machine_code.items[0]);
}

test "lh" {
    const machine_code = try assemble(&std.testing.allocator, "lh x21 -32(x22)");
    defer machine_code.deinit();
    try std.testing.expectEqual(@as(u32, 0xFE0B1A83), machine_code.items[0]);
}

test "lw" {
    const machine_code = try assemble(&std.testing.allocator, "lw x23 64(x24)");
    defer machine_code.deinit();
    try std.testing.expectEqual(@as(u32, 0x040C2B83), machine_code.items[0]);
}

test "lbu" {
    const machine_code = try assemble(&std.testing.allocator, "lbu x25 16(x26)");
    defer machine_code.deinit();
    try std.testing.expectEqual(@as(u32, 0x010D4C83), machine_code.items[0]);
}

test "lhu" {
    const machine_code = try assemble(&std.testing.allocator, "lhu x27 -128(x28)");
    defer machine_code.deinit();
    try std.testing.expectEqual(@as(u32, 0xF80E5D83), machine_code.items[0]);
}

test "sb" {
    const machine_code = try assemble(&std.testing.allocator, "sb s4 0(s4)");
    defer machine_code.deinit();
    try std.testing.expectEqual(@as(u32, 0x14a0023), machine_code.items[0]);
}

test "sh" {
    const machine_code = try assemble(&std.testing.allocator, "sh s5 2(s5)");
    defer machine_code.deinit();
    try std.testing.expectEqual(@as(u32, 0x15a9123), machine_code.items[0]);
}

test "sw" {
    const machine_code = try assemble(&std.testing.allocator, "sw s6 3(s6)");
    defer machine_code.deinit();
    try std.testing.expectEqual(@as(u32, 0x16b21a3), machine_code.items[0]);
}

// TODO: these are more than likely broken, ai generated. fix them

// test "beq" {
//     const source =
//         \\beq s7 s7 label
//         \\  addi x0 x0 0
//         \\  addi x0 x0 0
//         \\label:
//         \\  addi x0 x0 0
//         \\
//     ;
//     const machine_code = try assemble(&std.testing.allocator, source);
//     defer machine_code.deinit();

//     try std.testing.expectEqual(@as(u32, 0x17b8163), machine_code.items[0]);

//     try std.testing.expectEqual(@as(u32, 0x00000013), machine_code.items[1]);
//     try std.testing.expectEqual(@as(u32, 0x00000013), machine_code.items[2]);
//     try std.testing.expectEqual(@as(u32, 0x00000013), machine_code.items[3]);
// }

// test "bne" {
//     const source =
//         \\bne t0 t0 label
//         \\  addi x0 x0 0
//         \\  addi x0 x0 0
//         \\label:
//         \\  addi x0 x0 0
//         \\
//     ;
//     const machine_code = try assemble(&std.testing.allocator, source);
//     defer machine_code.deinit();

//     try std.testing.expectEqual(@as(u32, 0x529163), machine_code.items[0]);

//     try std.testing.expectEqual(@as(u32, 0x00000013), machine_code.items[1]);
//     try std.testing.expectEqual(@as(u32, 0x00000013), machine_code.items[2]);
//     try std.testing.expectEqual(@as(u32, 0x00000013), machine_code.items[3]);
// }

// test "blt" {
//     const source =
//         \\blt t1 t1 label
//         \\  addi x0 x0 0
//         \\  addi x0 x0 0
//         \\label:
//         \\  addi x0 x0 0
//         \\
//     ;
//     const machine_code = try assemble(&std.testing.allocator, source);
//     defer machine_code.deinit();

//     try std.testing.expectEqual(@as(u32, 0x634263), machine_code.items[0]);

//     try std.testing.expectEqual(@as(u32, 0x00000013), machine_code.items[1]);
//     try std.testing.expectEqual(@as(u32, 0x00000013), machine_code.items[2]);
//     try std.testing.expectEqual(@as(u32, 0x00000013), machine_code.items[3]);
// }

// test "bge" {
//     const source =
//         \\bge t2 t2 label
//         \\  addi x0 x0 0
//         \\  addi x0 x0 0
//         \\label:
//         \\  addi x0 x0 0
//         \\
//     ;
//     const machine_code = try assemble(&std.testing.allocator, source);
//     defer machine_code.deinit();

//     try std.testing.expectEqual(@as(u32, 0x73d163), machine_code.items[0]);

//     try std.testing.expectEqual(@as(u32, 0x00000013), machine_code.items[1]);
//     try std.testing.expectEqual(@as(u32, 0x00000013), machine_code.items[2]);
//     try std.testing.expectEqual(@as(u32, 0x00000013), machine_code.items[3]);
// }

// test "bltu" {
//     const source =
//         \\bltu t3 t3 label
//         \\  addi x0 x0 0
//         \\  addi x0 x0 0
//         \\label:
//         \\  addi x0 x0 0
//         \\
//     ;
//     const machine_code = try assemble(&std.testing.allocator, source);
//     defer machine_code.deinit();

//     try std.testing.expectEqual(@as(u32, 0x1ce6163), machine_code.items[0]);

//     try std.testing.expectEqual(@as(u32, 0x00000013), machine_code.items[1]);
//     try std.testing.expectEqual(@as(u32, 0x00000013), machine_code.items[2]);
//     try std.testing.expectEqual(@as(u32, 0x00000013), machine_code.items[3]);
// }

// test "bgeu" {
//     const source =
//         \\bgeu t4 t4 label
//         \\  addi x0 x0 0
//         \\  addi x0 x0 0
//         \\label:
//         \\  addi x0 x0 0
//         \\
//     ;
//     const machine_code = try assemble(&std.testing.allocator, source);
//     defer machine_code.deinit();

//     try std.testing.expectEqual(@as(u32, 0x1def163), machine_code.items[0]);

//     try std.testing.expectEqual(@as(u32, 0x00000013), machine_code.items[1]);
//     try std.testing.expectEqual(@as(u32, 0x00000013), machine_code.items[2]);
//     try std.testing.expectEqual(@as(u32, 0x00000013), machine_code.items[3]);
// }

test "lui" {
    const machine_code = try assemble(&std.testing.allocator, "lui t5 3");
    defer machine_code.deinit();
    try std.testing.expectEqual(@as(u32, 0x3f37), machine_code.items[0]);
}

test "auipc" {
    const machine_code = try assemble(&std.testing.allocator, "auipc t6 3");
    defer machine_code.deinit();
    try std.testing.expectEqual(@as(u32, 0x3f97), machine_code.items[0]);
}

// test "jal" {
//     const machine_code = try assemble(&std.testing.allocator, "jal ra 0");
//     defer machine_code.deinit();
//     try std.testing.expectEqual(@as(u32, 0xef), machine_code.items[0]);
// }

// test "jalr" {
//     const machine_code = try assemble(&std.testing.allocator, "jalr sp sp 3");
//     defer machine_code.deinit();
//     try std.testing.expectEqual(@as(u32, 0x310167), machine_code.items[0]);
// }
