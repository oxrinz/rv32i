const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn is_binary_operator(token: TokenType) bool {
    switch (token) {
        .PLUS, .MINUS, .STAR, .SLASH, .PERCENTAGE, .AMPERSAND, .PIPE, .CARET, .LEFT_SHIFT, .RIGHT_SHIFT, .AMPERSAND_AMPERSAND, .PIPE_PIPE, .BANG, .BANG_EQUAL, .EQUAL, .EQUAL_EQUAL, .GREATER, .GREATER_EQUAL, .LESS, .LESS_EQUAL => return true,
        else => return false,
    }
}

pub fn is_in_place_starter(token: TokenType) bool {
    switch (token) {
        .PLUS, .MINUS, .STAR, .SLASH, .PERCENTAGE, .AMPERSAND, .PIPE, .CARET, .LEFT_SHIFT, .RIGHT_SHIFT => return true,
        else => return false,
    }
}

pub const TokenType = enum {
    LEFT_PAREN,
    RIGHT_PAREN,
    LEFT_BRACE,
    RIGHT_BRACE,

    COMMA,
    DOT,

    MINUS,
    PLUS,

    SEMICOLON,
    SLASH,
    STAR,
    PERCENTAGE,

    BANG,
    BANG_EQUAL,
    EQUAL,
    EQUAL_EQUAL,
    GREATER,
    GREATER_EQUAL,
    LESS,
    LESS_EQUAL,

    IDENTIFIER,
    STRING,
    NUMBER,

    INT,
    IF,
    ELSE,
    VOID,
    RETURN,

    QUESTION_MARK,
    COLON,

    AMPERSAND,
    AMPERSAND_AMPERSAND,
    PIPE,
    PIPE_PIPE,
    CARET,
    LEFT_SHIFT,
    RIGHT_SHIFT,

    WHILE,
    DO,
    FOR,
    BREAK,
    CONTINUE,
};

pub const Literal = union(enum) { string: []const u8, number: i32 };

pub const Token = struct {
    type: TokenType,
    literal: ?Literal,
    line: usize,

    pub fn init(token_type: TokenType, literal: ?Literal, line: usize) Token {
        return .{
            .type = token_type,
            .literal = literal,
            .line = line,
        };
    }
};
