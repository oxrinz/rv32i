const std = @import("std");
const builtin = @import("builtin");
const testing = @import("testing.zig");
const Lexer = @import("frontend/lexer.zig").Lexer;
const Parser = @import("frontend/parser.zig").Parser;
const SemanticAnalysis = @import("frontend/semantic-analysis.zig").SemanticAnalysis;
const Generator = @import("middleend/gen.zig").Generator;
const Emitter = @import("backend/emission.zig").Emitter;
const diagnostics = @import("diagnostics.zig");
const prettyprinter = @import("prettyprinter.zig");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    defer diagnostics.arena.deinit();
    const allocator = arena.allocator();

    const debug_str = std.process.getEnvVarOwned(allocator, "DEBUG") catch "";
    defer if (debug_str.len > 0) allocator.free(debug_str);
    const debug_value = if (debug_str.len > 0)
        std.fmt.parseInt(u8, debug_str, 10) catch 0
    else
        0;

    const args = try std.process.argsAlloc(allocator);
    if (args.len != 2) {
        std.debug.print("Usage: {s} <source.c>\n", .{args[0]});
        std.process.exit(1);
    }

    const file_path = args[1];
    if (!std.mem.endsWith(u8, file_path, ".c")) {
        std.debug.print("Error: File must have .c extension\n", .{});
        std.process.exit(1);
    }

    const file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();

    const file_size = try file.getEndPos();
    const source = try allocator.alloc(u8, file_size);
    const bytes_read = try file.readAll(source);

    if (bytes_read != file_size) {
        std.debug.print("Error: Could not read entire file\n", .{});
        std.process.exit(1);
    }

    const assembly: []const u8 = generate(source, allocator, debug_value) catch {
        diagnostics.printAll();
        std.process.exit(1);
    };

    const dirname = std.fs.path.dirname(file_path) orelse ".";
    const stem = std.fs.path.stem(file_path);

    var path_buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    const output_path = try std.fmt.bufPrint(&path_buf, "{s}/{s}.asm", .{
        dirname,
        stem,
    });

    const out_file = try std.fs.cwd().createFile(
        output_path,
        .{},
    );
    defer out_file.close();

    try out_file.writeAll(assembly);
}

fn generate(input: []const u8, allocator: std.mem.Allocator, debug_value: i32) ![]const u8 {
    var lexer = Lexer.init(allocator, input);
    lexer.scan();

    if (debug_value == 1 and builtin.is_test == false) {
        std.debug.print("\n======== Tokens ========\n", .{});
        for (lexer.tokens.items) |token| {
            std.debug.print("{s} '{?}' at line {d}\n", .{
                @tagName(token.type),
                token.literal,
                token.line,
            });
        }
        std.debug.print("========================\n", .{});
    }

    var parser = Parser.init(lexer.tokens.items, allocator);
    const program_definition = try parser.parse();

    if (debug_value == 1 and builtin.is_test == false) {
        std.debug.print("\n======== Program ========\n", .{});
        prettyprinter.printProgram(program_definition);
        std.debug.print("===========================\n", .{});
    }

    var semantic = SemanticAnalysis.init(allocator);
    const analyzed_program_definition = semantic.analyze(program_definition) catch |err| {
        return err;
    };

    if (debug_value == 1 and builtin.is_test == false) {
        std.debug.print("\n=== Semantic analysis ===\n", .{});
        prettyprinter.printProgram(analyzed_program_definition);
        std.debug.print("===========================\n", .{});
    }

    var generator = Generator.init(analyzed_program_definition, allocator);
    const program = try generator.generate();

    var emitter = Emitter.init(program);

    return try emitter.getAssemblyString(allocator);
}

test "basic addition" {
    const input =
        \\int main()
        \\{
        \\ return 2 + 6;
        \\}
    ;

    const check = testing.WireCheck{
        .tick = 10,
        .wire = "alu_inst.rd_data",
        .value = 8,
    };

    try testing.testWithSystemVerilog("basic_addition", input, &[_]testing.WireCheck{check});
}

test "basic precedence" {
    const input =
        \\int main()
        \\{
        \\ return 10 - 6 + 2 * 4;
        \\}
    ;

    const check = testing.WireCheck{
        .tick = 18,
        .wire = "alu_inst.rd_data",
        .value = 12,
    };

    try testing.testWithSystemVerilog("basic_precedence", input, &[_]testing.WireCheck{check});
}

test "basic precedence 2" {
    const input =
        \\int main()
        \\{
        \\ return 20 - 6 * (4 - 2);
        \\}
    ;

    const check = testing.WireCheck{
        .tick = 18,
        .wire = "alu_inst.rd_data",
        .value = 8,
    };

    try testing.testWithSystemVerilog("basic_precedence_2", input, &[_]testing.WireCheck{check});
}

test "and short circuit 1" {
    const input =
        \\int main()
        \\{
        \\    return 20 == 20 && 10 != 5;
        \\}
    ;

    const check = testing.WireCheck{
        .tick = 24,
        .wire = "instr_mem.addr",
        .value = 12,
    };

    try testing.testWithSystemVerilog("and_short_circuit_1", input, &[_]testing.WireCheck{check});
}

test "or short circuit 1" {
    const input =
        \\int main()
        \\{
        \\    return 3 > 3 || 19 != 19 || 4 <= 3 || 2 >= 2 || 2 != 2;
        \\}
    ;

    const check = testing.WireCheck{
        .tick = 50,
        .wire = "instr_mem.addr",
        .value = 30,
    };

    try testing.testWithSystemVerilog("or_short_circuit_1", input, &[_]testing.WireCheck{check});
}

test "and short circuit 2" {
    const input =
        \\int main()
        \\{
        \\    return 2 == 2 && 2 <= 1 && 5 > 3;
        \\}
    ;

    const check = testing.WireCheck{
        .tick = 26,
        .wire = "instr_mem.addr",
        .value = 16,
    };

    try testing.testWithSystemVerilog("and_short_circuit_2", input, &[_]testing.WireCheck{check});
}

test "variables 1" {
    const input =
        \\int main()
        \\{
        \\    int beh = 5 + 1;
        \\    int bah = beh - 1 * 2;
        \\    return bah + 8;
        \\}
        \\
    ;

    const check = testing.WireCheck{
        .tick = 38,
        .wire = "alu_inst.rd_data",
        .value = 12,
    };

    try testing.testWithSystemVerilog("variables_1", input, &[_]testing.WireCheck{check});
}

test "variables 2" {
    const input =
        \\int main()
        \\{
        \\    int beh = 5 + 1;
        \\    int bah = beh - 1 * 2;
        \\    int bumbam = beh + bah;
        \\    return bumbam + beh;
        \\}
        \\
    ;

    const check = testing.WireCheck{
        .tick = 54,
        .wire = "alu_inst.rd_data",
        .value = 16,
    };

    try testing.testWithSystemVerilog("variables_2", input, &[_]testing.WireCheck{check});
}

test "if 1" {
    const input =
        \\int main()
        \\{
        \\    int ab = 0;
        \\    if (ab != 0)
        \\        ab = 2;
        \\    else
        \\        ab = 19;
        \\}
        \\
    ;

    const check = testing.WireCheck{
        .tick = 34,
        .wire = "instr_mem.addr",
        .value = 21,
    };

    try testing.testWithSystemVerilog("if_1", input, &[_]testing.WireCheck{check});
}

test "if 2" {
    const input =
        \\int main()
        \\{
        \\    int ab = 0;
        \\    if (ab == 0)
        \\        if (ab != 0)
        \\            ab = 2;
        \\        else
        \\            ab = 7;
        \\    else
        \\        ab = 19;
        \\}
        \\
    ;

    const check = testing.WireCheck{
        .tick = 38,
        .wire = "instr_mem.addr",
        .value = 23,
    };

    try testing.testWithSystemVerilog("if_2", input, &[_]testing.WireCheck{check});
}

test "if 3" {
    const input =
        \\int main()
        \\{
        \\    int ab = 0;
        \\    if (ab != 0)
        \\        ab = 2;
        \\
        \\    ab = 62;
        \\}
        \\
    ;

    const check = testing.WireCheck{
        .tick = 26,
        .wire = "alu_inst.rd_data",
        .value = 62,
    };

    try testing.testWithSystemVerilog("if_3", input, &[_]testing.WireCheck{check});
}

test "compound if 1" {
    const input =
        \\int main()
        \\{
        \\    int ab = 0;
        \\    if (ab == 1)
        \\    {
        \\        ab = 5;
        \\    }
        \\    else if (ab == 2)
        \\    {
        \\        ab = 4;
        \\    }
        \\    else
        \\    {
        \\        ab = 3;
        \\        ab += 11;
        \\    }
        \\}
        \\
    ;

    const check = testing.WireCheck{
        .tick = 48,
        .wire = "alu_inst.rd_data",
        .value = 14,
    };

    try testing.testWithSystemVerilog("compund_if_1", input, &[_]testing.WireCheck{check});
}

test "multiple scopes variable resolution" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const input =
        \\int main()
        \\{
        \\    int x = 1;
        \\    {
        \\        int x = 2;
        \\        if (x > 1) {
        \\            x = 3;
        \\            int x = 4;
        \\        }
        \\        return x;
        \\    }
        \\    return x;
        \\}
        \\
    ;

    var lexer = Lexer.init(allocator, input);
    lexer.scan();
    var parser = Parser.init(lexer.tokens.items, allocator);
    const program_definition = try parser.parse();

    var semantic = SemanticAnalysis.init(allocator);

    const analyzed_program_definition = try semantic.analyze(program_definition);

    try std.testing.expectEqualStrings("var_0", analyzed_program_definition.function[0].body.?.block_items[0].declaration.variable_declaration.identifier);
    try std.testing.expectEqualStrings("var_1", analyzed_program_definition.function[0].body.?.block_items[1].statement.compound.block_items[0].declaration.variable_declaration.identifier);
    try std.testing.expectEqualStrings("var_1", analyzed_program_definition.function[0].body.?.block_items[1].statement.compound.block_items[1].statement.if_.then.compound.block_items[0].statement.exp.assignment.left.variable.identifier);
    try std.testing.expectEqualStrings("var_2", analyzed_program_definition.function[0].body.?.block_items[1].statement.compound.block_items[1].statement.if_.then.compound.block_items[1].declaration.variable_declaration.identifier);
    try std.testing.expectEqualStrings("var_1", analyzed_program_definition.function[0].body.?.block_items[1].statement.compound.block_items[2].statement.ret.exp.variable.identifier);
    try std.testing.expectEqualStrings("var_0", analyzed_program_definition.function[0].body.?.block_items[2].statement.ret.exp.variable.identifier);
}

test "loop labeling" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const input =
        \\int main()
        \\{
        \\    int a = 16;
        \\    int b = 2;
        \\    while (a > 0)
        \\    {
        \\        for (int i = 0; i < 10; i += 1)
        \\        {
        \\            if (i % 2 == 0)
        \\                continue;
        \\            a = a / 2;
        \\        }
        \\        if (a == b)
        \\            break;
        \\    }
        \\}
        \\
    ;

    var lexer = Lexer.init(allocator, input);
    lexer.scan();
    var parser = Parser.init(lexer.tokens.items, allocator);
    const program_definition = try parser.parse();

    var semantic = SemanticAnalysis.init(allocator);
    const analyzed_program_definition = try semantic.analyze(program_definition);

    try std.testing.expectEqualStrings("loop_0", analyzed_program_definition.function[0].body.?.block_items[2].statement.while_.identifier.?);
    try std.testing.expectEqualStrings("loop_1", analyzed_program_definition.function[0].body.?.block_items[2].statement.while_.body.compound.block_items[0].statement.for_.identifier.?);
    try std.testing.expectEqualStrings("loop_1", analyzed_program_definition.function[0].body.?.block_items[2].statement.while_.body.compound.block_items[0].statement.for_.body.compound.block_items[0].statement.if_.then.continue_.identifier.?);
    try std.testing.expectEqualStrings("loop_0", analyzed_program_definition.function[0].body.?.block_items[2].statement.while_.body.compound.block_items[1].statement.if_.then.*.break_.identifier.?);
}

test "while loop" {
    const input =
        \\int main()
        \\{
        \\    int a = 16;
        \\    while (a > 12)
        \\    {
        \\        a -= 2;
        \\    }
        \\}
        \\
    ;

    const check = testing.WireCheck{
        .tick = 70,
        .wire = "instr_mem.addr",
        .value = 18,
    };

    try testing.testWithSystemVerilog("while_loop", input, &[_]testing.WireCheck{check});
}

test "do while loop" {
    const input =
        \\int main()
        \\{
        \\    int a = 16;
        \\    do {
        \\        a -= 2;
        \\    } while (a > 12);
        \\}
        \\
    ;

    const check = testing.WireCheck{
        .tick = 56,
        .wire = "instr_mem.addr",
        .value = 17,
    };

    try testing.testWithSystemVerilog("do_while_loop", input, &[_]testing.WireCheck{check});
}

test "do while break loop" {
    const input =
        \\int main()
        \\{
        \\    int a = 16;
        \\    do
        \\    {
        \\        a -= 2;
        \\        if (a <= 12)
        \\            break;
        \\    } while (a > 10);
        \\}
        \\
    ;

    const check = testing.WireCheck{
        .tick = 72,
        .wire = "instr_mem.addr",
        .value = 24,
    };

    try testing.testWithSystemVerilog("do_while_break_loop", input, &[_]testing.WireCheck{check});
}

test "for continue loop" {
    const input =
        \\int main()
        \\{
        \\    int a = 16;
        \\    for (int i = 0; i < 4; i += 1)
        \\    {
        \\        if (i % 2 == 0)
        \\        {
        \\            a += 2;
        \\            continue;
        \\        }
        \\        a += 1;
        \\    }
        \\    a -= 10;
        \\}
        \\
    ;

    const check = testing.WireCheck{
        .tick = 246,
        .wire = "alu_inst.rd_data",
        .value = 12,
    };

    try testing.testWithSystemVerilog("for_continue_loop", input, &[_]testing.WireCheck{check});
}
