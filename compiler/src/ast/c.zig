const std = @import("std");

pub const BinaryOperator = enum {
    Add,
    Subtract,
    Multiply,
    Divide,
    Remainder,

    Bitwise_AND,
    Bitwise_OR,
    Bitwise_XOR,
    Left_Shift,
    Right_Shift,

    Less,
    Less_Or_Equal,
    Greater,
    Greater_Or_Equal,
    Equal,
    Not_Equal,
    And,
    Or,

    pub fn getType(op: *const BinaryOperator) enum { ARITHMETIC, BITWISE, COMPARISON, SHORT_CIRCUIT } {
        switch (op.*) {
            .Add, .Subtract, .Multiply, .Divide, .Remainder => return .ARITHMETIC,
            .Bitwise_AND, .Bitwise_OR, .Bitwise_XOR, .Left_Shift, .Right_Shift => return .BITWISE,
            .Less, .Less_Or_Equal, .Greater, .Greater_Or_Equal, .Equal, .Not_Equal => return .COMPARISON,
            .And, .Or => return .SHORT_CIRCUIT,
        }
    }
};

pub const Binary = struct {
    operator: BinaryOperator,
    left: *Expression,
    right: *Expression,
};

pub const Variable = struct {
    identifier: []const u8,
};

pub const Assignment = struct {
    left: *Expression,
    right: *Expression,
};

pub const FunctionCall = struct {
    identifier: []const u8,
    args: []*Expression,
};

pub const Expression = union(enum) {
    constant: i32,
    binary: Binary,
    variable: Variable,
    assignment: Assignment,
    function_call: FunctionCall,
};

pub const Return = struct {
    exp: Expression,
};

pub const If = struct {
    condition: Expression,
    then: *Statement,
    else_: ?*Statement,
};

pub const While = struct {
    condition: Expression,
    body: *Statement,
    identifier: ?[]const u8,
};

pub const DoWhile = struct {
    condition: Expression,
    body: *Statement,
    identifier: ?[]const u8,
};

pub const ForInit = union(enum) {
    init_decl: VariableDeclaration,
    init_exp: ?Expression,
};

pub const For = struct {
    init: ForInit,
    condition: ?Expression,
    post: ?Expression,
    body: *Statement,
    identifier: ?[]const u8,
};

pub const Break = struct {
    identifier: ?[]const u8,
};

pub const Continue = struct {
    identifier: ?[]const u8,
};

pub const Statement = union(enum) {
    ret: Return,
    exp: Expression,
    compound: Block,
    if_: If,
    break_: Break,
    continue_: Continue,
    while_: While,
    do_while: DoWhile,
    for_: For,
};

pub const VariableDeclaration = struct {
    identifier: []const u8,
    initial: ?Expression,
};

pub const FunctionDeclaration = struct {
    identifier: []const u8,
    params: [][]const u8,
    body: ?Block,
};

pub const Declaration = union(enum) {
    variable_declaration: VariableDeclaration,
    function_declaration: FunctionDeclaration,
};

pub const BlockItem = union(enum) {
    statement: Statement,
    declaration: Declaration,
};

pub const Block = struct {
    block_items: []BlockItem,
};

pub const Program = struct {
    function: []FunctionDeclaration,
};
