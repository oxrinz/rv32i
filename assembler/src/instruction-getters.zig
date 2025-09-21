const std = @import("std");
const instr_types = @import("instruction-types.zig");
const RTypeInstruction = instr_types.RTypeInstruction;
const ITypeInstruction = instr_types.ITypeInstruction;
const STypeInstruction = instr_types.STypeInstruction;
const BTypeInstruction = instr_types.BTypeInstruction;
const UTypeInstruction = instr_types.UTypeInstruction;
const JTypeInstruction = instr_types.JTypeInstruction;

pub fn getRTypeInstruction(instruction: []const u8) !RTypeInstruction {
    if (std.mem.eql(u8, instruction, "add")) return .ADD;
    if (std.mem.eql(u8, instruction, "sub")) return .SUB;
    if (std.mem.eql(u8, instruction, "sll")) return .SLL;
    if (std.mem.eql(u8, instruction, "slt")) return .SLT;
    if (std.mem.eql(u8, instruction, "sltu")) return .SLTU;
    if (std.mem.eql(u8, instruction, "xor")) return .XOR;
    if (std.mem.eql(u8, instruction, "srl")) return .SRL;
    if (std.mem.eql(u8, instruction, "sra")) return .SRA;
    if (std.mem.eql(u8, instruction, "or")) return .OR;
    if (std.mem.eql(u8, instruction, "and")) return .AND;

    // m extension
    if (std.mem.eql(u8, instruction, "mul")) return .MUL;
    if (std.mem.eql(u8, instruction, "mulh")) return .MULH;
    if (std.mem.eql(u8, instruction, "mulsu")) return .MULSU;
    if (std.mem.eql(u8, instruction, "mulu")) return .MULU;
    if (std.mem.eql(u8, instruction, "div")) return .DIV;
    if (std.mem.eql(u8, instruction, "divu")) return .DIVU;
    if (std.mem.eql(u8, instruction, "rem")) return .REM;
    if (std.mem.eql(u8, instruction, "remu")) return .REMU;
    unreachable;
}

pub fn getITypeInstruction(instruction: []const u8) !ITypeInstruction {
    if (std.mem.eql(u8, instruction, "addi")) return .ADDI;
    if (std.mem.eql(u8, instruction, "slti")) return .SLTI;
    if (std.mem.eql(u8, instruction, "sltiu")) return .SLTIU;
    if (std.mem.eql(u8, instruction, "xori")) return .XORI;
    if (std.mem.eql(u8, instruction, "ori")) return .ORI;
    if (std.mem.eql(u8, instruction, "andi")) return .ANDI;
    if (std.mem.eql(u8, instruction, "slli")) return .SLLI;
    if (std.mem.eql(u8, instruction, "srli")) return .SRLI;
    if (std.mem.eql(u8, instruction, "srai")) return .SRAI;
    if (std.mem.eql(u8, instruction, "lb")) return .LB;
    if (std.mem.eql(u8, instruction, "lh")) return .LH;
    if (std.mem.eql(u8, instruction, "lw")) return .LW;
    if (std.mem.eql(u8, instruction, "lbu")) return .LBU;
    if (std.mem.eql(u8, instruction, "lhu")) return .LHU;
    if (std.mem.eql(u8, instruction, "jalr")) return .JALR;
    unreachable;
}

pub fn getSTypeInstruction(instruction: []const u8) !STypeInstruction {
    if (std.mem.eql(u8, instruction, "sb")) return .SB;
    if (std.mem.eql(u8, instruction, "sh")) return .SH;
    if (std.mem.eql(u8, instruction, "sw")) return .SW;
    unreachable;
}

pub fn getBTypeInstruction(instruction: []const u8) !BTypeInstruction {
    if (std.mem.eql(u8, instruction, "beq")) return .BEQ;
    if (std.mem.eql(u8, instruction, "bne")) return .BNE;
    if (std.mem.eql(u8, instruction, "blt")) return .BLT;
    if (std.mem.eql(u8, instruction, "bge")) return .BGE;
    if (std.mem.eql(u8, instruction, "bltu")) return .BLTU;
    if (std.mem.eql(u8, instruction, "bgeu")) return .BGEU;
    unreachable;
}

pub fn getUTypeInstruction(instruction: []const u8) !UTypeInstruction {
    if (std.mem.eql(u8, instruction, "lui")) return .LUI;
    if (std.mem.eql(u8, instruction, "auipc")) return .AUIPC;
    unreachable;
}

pub fn getJTypeInstruction(instruction: []const u8) !JTypeInstruction {
    if (std.mem.eql(u8, instruction, "jal")) return .JAL;
    unreachable;
}
