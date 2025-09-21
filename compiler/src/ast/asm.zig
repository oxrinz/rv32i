const std = @import("std");

// utils for enums, preferably have this in a separate file
pub fn EnumMethods(comptime T: type) type {
    return struct {
        pub fn toString(self: T) []const u8 {
            const str = @tagName(self);
            comptime var max_len = 0;
            inline for (@typeInfo(T).Enum.fields) |field| {
                max_len = @max(max_len, field.name.len);
            }
            var buf: [max_len]u8 = undefined;
            return std.ascii.lowerString(&buf, str);
        }
    };
}

// TODO: there has to be a cleaner way to do this
pub fn convert(instr: InstructionType) union(enum) { rtype: RType_Inst, itype: IType_Inst, btype: BType_Inst, stype: SType_Inst, utype: UType_Inst, jtype: JType_Inst } {
    const instr_name = @tagName(instr);

    inline for (@typeInfo(RType_Inst).Enum.fields) |field| {
        if (std.mem.eql(u8, instr_name, field.name)) {
            return .{ .rtype = @field(RType_Inst, field.name) };
        }
    }

    inline for (@typeInfo(IType_Inst).Enum.fields) |field| {
        if (std.mem.eql(u8, instr_name, field.name)) {
            return .{ .itype = @field(IType_Inst, field.name) };
        }
    }

    inline for (@typeInfo(BType_Inst).Enum.fields) |field| {
        if (std.mem.eql(u8, instr_name, field.name)) {
            return .{ .btype = @field(BType_Inst, field.name) };
        }
    }

    inline for (@typeInfo(SType_Inst).Enum.fields) |field| {
        if (std.mem.eql(u8, instr_name, field.name)) {
            return .{ .stype = @field(SType_Inst, field.name) };
        }
    }

    inline for (@typeInfo(UType_Inst).Enum.fields) |field| {
        if (std.mem.eql(u8, instr_name, field.name)) {
            return .{ .utype = @field(UType_Inst, field.name) };
        }
    }

    inline for (@typeInfo(JType_Inst).Enum.fields) |field| {
        if (std.mem.eql(u8, instr_name, field.name)) {
            return .{ .jtype = @field(JType_Inst, field.name) };
        }
    }

    std.debug.print("Can't convert {} instruction\n", .{instr});

    unreachable;
}

pub const Reg = enum {
    zero,
    ra,
    sp,
    t0,
    t1,
    t2,
    fp,
    a0,
    a1,
    a2,
    a3,
    a4,
    a5,
    a6,
    a7,
    t3,

    pub fn toString(self: Reg) []const u8 {
        return @tagName(self);
    }
};

const Addi = struct {
    source: Reg,
    destination: Reg,
    imm: u12,
};

pub const InstructionType = enum {
    ADD,
    SUB,
    XOR,
    OR,
    AND,
    SLL,
    SRL,
    SRA,
    SLT,
    SLTU,
    MUL,
    MULH,
    MULSU,
    MULU,
    DIV,
    DIVU,
    REM,
    REMU,

    ADDI,
    // SUB,
    XORI,
    // OR,
    // AND,
    // SLL,
    // SRL,
    // SRA,
    SLTI,
    SLTIU,

    LB,
    LH,
    LW,
    LBU,
    LHU,

    SB,
    SH,
    SW,

    BEQ,
    BNE,
    BLT,
    BGE,
    BLTU,
    BGEU,

    LUI,
    AUIPC,

    JAL,
    JALR,
};

pub const RType_Inst = enum {
    ADD,
    SUB,
    XOR,
    OR,
    AND,
    SLL,
    SRL,
    SRA,
    SLT,
    SLTU,

    MUL,
    MULH,
    MULSU,
    MULU,
    DIV,
    DIVU,
    REM,
    REMU,

    pub usingnamespace EnumMethods(RType_Inst);
};

pub const IType_Inst = enum {
    ADDI,
    // SUB,
    XORI,
    // OR,
    // AND,
    // SLL,
    // SRL,
    // SRA,
    SLTI,
    SLTIU,
    // MUL,
    // MULH,
    // MULSU,
    // MULU,
    // DIV,
    // DIVU,
    // REM,
    // REMU,

    LB,
    LH,
    LW,
    LBU,
    LHU,

    JALR,

    pub usingnamespace EnumMethods(IType_Inst);
};

pub const BType_Inst = enum {
    BEQ,
    BNE,
    BLT,
    BGE,
    BLTU,
    BGEU,

    pub usingnamespace EnumMethods(BType_Inst);
};

pub const SType_Inst = enum {
    SB,
    SH,
    SW,

    pub usingnamespace EnumMethods(SType_Inst);
};

pub const UType_Inst = enum {
    LUI,
    AUIPC,

    pub usingnamespace EnumMethods(UType_Inst);
};

pub const JType_Inst = enum {
    JAL,

    pub usingnamespace EnumMethods(JType_Inst);
};

pub const RType = struct {
    instr: RType_Inst,
    source1: Reg,
    source2: Reg,
    destination: Reg,
};

pub const IType = struct {
    instr: IType_Inst,
    source: Reg,
    destination: Reg,
    immediate: i32,
};

pub const BType = struct {
    instr: BType_Inst,
    source1: Reg,
    source2: Reg,
    label: []const u8,
};

pub const SType = struct {
    instr: SType_Inst,
    source1: Reg,
    source2: Reg,
    immediate: i32,
};

pub const UType = struct {
    instr: UType_Inst,
    destination: Reg,
    immediate: i32,
};

pub const JType = struct {
    instr: JType_Inst,
    destination: Reg,
    label: []const u8,
};

const Label = struct {
    name: []const u8,
};

pub const Instruction = union(enum) {
    rtype: RType,
    itype: IType,
    stype: SType,
    btype: BType,
    utype: UType,
    jtype: JType,

    label: Label,
};

pub const FunctionDefinition = struct {
    identifier: []const u8,
    instructions: []Instruction,
};

pub const Program = struct {
    function: FunctionDefinition,
};
