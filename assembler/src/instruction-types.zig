pub const RTypeInstruction = enum {
    ADD,
    SUB,
    SLL,
    SLT,
    SLTU,
    XOR,
    SRL,
    SRA,
    OR,
    AND,
};

pub const ITypeInstruction = enum {
    ADDI,
    SLTI,
    SLTIU,
    XORI,
    ORI,
    ANDI,
    SLLI,
    SRLI,
    SRAI,
    LB,
    LH,
    LW,
    LBU,
    LHU,
    JALR,
};

pub const STypeInstruction = enum {
    SB,
    SH,
    SW,
};

pub const BTypeInstruction = enum {
    BEQ,
    BNE,
    BLT,
    BGE,
    BLTU,
    BGEU,
};

pub const UTypeInstruction = enum {
    LUI,
    AUIPC,
};

pub const JTypeInstruction = enum {
    JAL,
};
