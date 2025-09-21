const std = @import("std");

pub var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
const allocator = arena.allocator();

var messages = std.ArrayList(Diagnostic).init(allocator);

const Diagnostic = struct {
    message: []const u8,
    line: ?usize,
    type: enum {
        PANIC,
        WARNING,
        ERROR,
    },
};

const ColorCode = struct {
    const reset = "\x1b[0m";
    const red = "\x1b[31m";
    const yellow = "\x1b[33m";
    const magenta = "\x1b[35m";
};

fn printMsg(msg: Diagnostic) !void {
    const stderr = std.io.getStdErr().writer();
    switch (msg.type) {
        .PANIC => {
            try stderr.print("{s}PANIC:{s}", .{ ColorCode.magenta, ColorCode.reset });
        },
        .WARNING => try stderr.print("{s}WARNING{s}", .{ ColorCode.yellow, ColorCode.reset }),
        .ERROR => {
            try stderr.print("{s}ERROR{s}", .{ ColorCode.red, ColorCode.reset });
        },
    }

    const lineInfo = if (msg.line) |line|
        try std.fmt.allocPrint(messages.allocator, "line {d}: ", .{line})
    else
        "";
    defer if (msg.line != null) messages.allocator.free(lineInfo);

    try stderr.print(" {s}{s}\n", .{ lineInfo, msg.message });
}

pub fn printAll() void {
    for (messages.items) |msg| {
        printMsg(msg) catch @panic("Failed to print error messages");
    }
}

pub fn addPanic(message: []const u8, line: ?usize) void {
    messages.append(.{
        .message = message,
        .line = line,
        .type = .PANIC,
    }) catch @panic("Failed to append panic message");
}

pub fn addError(message: []const u8, line: ?usize) void {
    messages.append(.{
        .message = message,
        .line = line,
        .type = .ERROR,
    }) catch @panic("Failed to append panic message");
}

pub fn addWarning(message: []const u8, line: ?usize) void {
    messages.append(.{
        .message = message,
        .line = line,
        .type = .WARNING,
    }) catch @panic("Failed to append panic message");
}
