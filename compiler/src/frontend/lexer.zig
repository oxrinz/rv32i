const std = @import("std");
const tokens = @import("tokens.zig");
const Token = tokens.Token;
const TokenType = tokens.TokenType;

var keywords: std.StringHashMap(TokenType) = undefined;

pub fn initKeywords(allocator: std.mem.Allocator) !void {
    keywords = std.StringHashMap(TokenType).init(allocator);

    try keywords.put("int", .INT);

    try keywords.put("void", .VOID);
    try keywords.put("return", .RETURN);

    try keywords.put("if", .IF);
    try keywords.put("else", .ELSE);

    try keywords.put("break", .BREAK);
    try keywords.put("continue", .CONTINUE);
    try keywords.put("while", .WHILE);
    try keywords.put("do", .DO);
    try keywords.put("for", .FOR);
}

pub const Lexer = struct {
    allocator: std.mem.Allocator,
    source: []const u8,
    tokens: std.ArrayList(Token),
    currentIndex: usize = 0,
    currentLine: usize = 1,
    start: usize = 0,

    pub fn init(allocator: std.mem.Allocator, source: []const u8) Lexer {
        initKeywords(allocator) catch @panic("gg");
        return .{
            .allocator = allocator,
            .source = source,
            .tokens = std.ArrayList(Token).init(allocator),
        };
    }

    pub fn deinit(self: *Lexer) void {
        keywords.deinit();
        self.tokens.deinit();
    }

    pub fn scan(self: *Lexer) void {
        while (self.currentIndex < self.source.len) {
            self.start = self.currentIndex;
            const token = self.scanToken();
            if (token) |t| self.tokens.append(t) catch @panic("out of memory");
        }
    }

    fn isAtEnd(self: *Lexer) bool {
        return self.currentIndex >= self.source.len;
    }

    fn advance(self: *Lexer) u8 {
        self.currentIndex += 1;
        return self.source[self.currentIndex - 1];
    }

    fn isDigit(self: *Lexer, c: u8) bool {
        _ = self;
        return c >= '0' and c <= '9';
    }

    fn isAlpha(self: *Lexer, c: u8) bool {
        _ = self;
        return (c >= 'a' and c <= 'z') or
            (c >= 'A' and c <= 'Z') or
            c == '_';
    }

    fn isAlphaNumeric(self: *Lexer, c: u8) bool {
        return self.isAlpha(c) or self.isDigit(c);
    }

    fn peek(self: *Lexer) u8 {
        if (self.isAtEnd()) return 0;
        return self.source[self.currentIndex];
    }

    fn match(self: *Lexer, expected: u8) bool {
        if (self.isAtEnd()) return false;

        if (self.source[self.currentIndex] != expected) return false;

        self.currentIndex += 1;
        return true;
    }

    fn scanComment(self: *Lexer) void {
        while (self.peek() != '\n' and !self.isAtEnd()) {
            _ = self.advance();
        }
    }

    fn string(self: *Lexer) ?Token {
        while (self.peek() != '"' and !self.isAtEnd()) {
            if (self.peek() == '\n') {
                self.currentLine += 1;
            }
            _ = self.advance();
        }

        if (self.isAtEnd()) {
            return null;
        }

        _ = self.advance();

        const value = self.source[self.start + 1 .. self.currentIndex - 1];

        const token = Token.init(.STRING, .{ .string = value }, self.currentLine);

        return token;
    }

    fn number(self: *Lexer) ?Token {
        while (self.isDigit(self.peek())) _ = self.advance();

        const number_str = self.source[self.start..self.currentIndex];

        const token = Token.init(.NUMBER, .{ .number = std.fmt.parseInt(i32, number_str, 10) catch @panic("failed to parse int") }, self.currentLine);
        return token;
    }

    fn identifier(self: *Lexer) ?Token {
        while (self.isAlphaNumeric(self.peek())) _ = self.advance();

        const value = self.source[self.start..self.currentIndex];
        const ttype = keywords.get(value) orelse TokenType.IDENTIFIER;

        const token = Token.init(ttype, .{ .string = value }, self.currentLine);
        return token;
    }

    pub fn scanToken(self: *Lexer) ?Token {
        const char = self.advance();

        const token_type: TokenType = switch (char) {
            '(' => .LEFT_PAREN,
            ')' => .RIGHT_PAREN,
            '{' => .LEFT_BRACE,
            '}' => .RIGHT_BRACE,
            ',' => .COMMA,
            '.' => .DOT,
            '-' => .MINUS,
            '+' => .PLUS,
            ';' => .SEMICOLON,
            '*' => .STAR,
            '%' => .PERCENTAGE,
            '?' => .QUESTION_MARK,
            ':' => .COLON,
            '&' => if (self.match('&')) .AMPERSAND_AMPERSAND else .AMPERSAND,
            '|' => if (self.match('|')) .PIPE_PIPE else .PIPE,
            '^' => .CARET,

            '!' => if (self.match('=')) .BANG_EQUAL else .BANG,
            '=' => if (self.match('=')) .EQUAL_EQUAL else .EQUAL,
            '<' => if (self.match('=')) .LESS_EQUAL else if (self.match('<')) .LEFT_SHIFT else .LESS,

            '>' => if (self.match('=')) .GREATER_EQUAL else if (self.match('>')) .RIGHT_SHIFT else .GREATER,

            '/' => blk: {
                const result: TokenType = if (self.match('/')) {
                    while (self.peek() != '\n' and !self.isAtEnd()) {
                        _ = self.advance();
                    }
                    if (!self.isAtEnd()) return self.scanToken() else return null;
                } else .SLASH;
                break :blk result;
            },
            '\n' => {
                self.currentLine += 1;
                return null;
            },
            ' ' => return null,
            '\r' => return null,
            '\t' => return null,
            '"',
            => {
                return self.string();
            },
            else => {
                if (self.isDigit(char)) return self.number();

                if (self.isAlpha(char)) return self.identifier();

                const msg = std.fmt.allocPrint(self.allocator, "unexpected character at line {}", .{self.currentLine}) catch @panic("try again");
                defer self.allocator.free(msg);
                @panic(msg);
            },
        };

        const token = Token.init(token_type, null, self.currentLine);
        return token;
    }
};
