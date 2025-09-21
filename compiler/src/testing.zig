pub usingnamespace @import("std").testing;
const std = @import("std");
const c_ast = @import("ast/c.zig");
const Lexer = @import("frontend/lexer.zig").Lexer;
const Parser = @import("frontend/parser.zig").Parser;
const SemanticAnalysis = @import("frontend/semantic-analysis.zig").SemanticAnalysis;
const Generator = @import("middleend/gen.zig").Generator;
const Emitter = @import("backend/emission.zig").Emitter;

pub fn cToSemanticAnalysis(input: []const u8) !c_ast.Program {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit(); // This single call will free all allocations at once
    const allocator = arena.allocator();

    var lexer = Lexer.init(allocator, input);
    lexer.scan();

    var parser = Parser.init(lexer.tokens.items, allocator);
    const program_definition = try parser.parse();

    var semantic = SemanticAnalysis.init(allocator);
    return try semantic.analyze(program_definition);
}

pub fn cToAST(input: []const u8) !c_ast.Program {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var lexer = Lexer.init(allocator, input);
    lexer.scan();

    var parser = Parser.init(lexer.tokens.items, allocator);
    return try parser.parse();
}

pub fn generate(input: []const u8, allocator: std.mem.Allocator) ![]const u8 {
    var lexer = Lexer.init(allocator, input);
    lexer.scan();

    var parser = Parser.init(lexer.tokens.items, allocator);
    const program_definition = try parser.parse();

    var semantic = SemanticAnalysis.init(allocator);
    const analyzed_program = try semantic.analyze(program_definition);

    var generator = Generator.init(analyzed_program, allocator);
    const generated_program = try generator.generate();

    var emitter = Emitter.init(generated_program);
    return try emitter.getAssemblyString(allocator);
}

fn runShellCommand(allocator: std.mem.Allocator, command: []const u8) ![]u8 {
    const max_output_size = 1024 * 1024;

    var child = std.process.Child.init(&[_][]const u8{ "sh", "-c", command }, allocator);

    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;

    try child.spawn();

    var stdout_buffer = try allocator.alloc(u8, max_output_size);
    errdefer allocator.free(stdout_buffer);
    var stdout_len: usize = 0;

    var stderr_buffer = try allocator.alloc(u8, max_output_size);
    defer allocator.free(stderr_buffer);
    var stderr_len: usize = 0;

    while (true) {
        const bytes_read = try child.stdout.?.read(stdout_buffer[stdout_len..]);
        if (bytes_read == 0) break;
        stdout_len += bytes_read;
        if (stdout_len >= max_output_size) break;
    }

    while (true) {
        const bytes_read = try child.stderr.?.read(stderr_buffer[stderr_len..]);
        if (bytes_read == 0) break;
        stderr_len += bytes_read;
        if (stderr_len >= max_output_size) break;
    }

    const term = try child.wait();

    if (term.Exited != 0) {
        std.debug.print("Test failed\n", .{});
        return error.TestFailed;
    }

    return allocator.realloc(stdout_buffer, stdout_len);
}

pub const WireCheck = struct {
    tick: u32,
    wire: []const u8,
    value: u32,
};

pub fn testWithSystemVerilog(
    test_name: []const u8,
    c_code: []const u8,
    wire_checks: []const WireCheck,
) !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    try std.fs.cwd().makePath("../temp");

    const assembly = try generate(c_code, allocator);

    const asm_path = try std.fmt.allocPrint(allocator, "../temp/{s}.asm", .{test_name});
    defer allocator.free(asm_path);
    const asm_file = try std.fs.cwd().createFile(asm_path, .{});
    defer asm_file.close();
    try asm_file.writeAll(assembly);

    const tb_content = try generateTestbench(test_name, wire_checks, allocator);

    const tb_path = try std.fmt.allocPrint(allocator, "../temp/{s}.sv", .{test_name});
    defer allocator.free(tb_path);
    const tb_file = try std.fs.cwd().createFile(tb_path, .{});
    defer tb_file.close();
    try tb_file.writeAll(tb_content);

    {
        const assemble_cmd = try std.fmt.allocPrint(allocator, "cd .. && cd assembler && zig build run -- \"../temp/{s}.asm\" ../program", .{test_name});
        defer allocator.free(assemble_cmd);
        _ = try runShellCommand(allocator, assemble_cmd);
    }

    {
        const iverilog_cmd = try std.fmt.allocPrint(allocator, "cd .. && iverilog -g2012 \"temp/{s}\" src/**.sv -o temp_output.vvp", .{tb_path});
        defer allocator.free(iverilog_cmd);
        _ = try runShellCommand(allocator, iverilog_cmd);
    }

    {
        const vvp_output = runShellCommand(allocator, "cd .. && vvp temp_output.vvp") catch |err| {
            const temp_out_path = try std.fmt.allocPrint(allocator, "../temp_output.vvp", .{});
            defer allocator.free(temp_out_path);
            std.fs.cwd().deleteFile(temp_out_path) catch {};
            return err;
        };

        const temp_out_path = try std.fmt.allocPrint(allocator, "../temp_output.vvp", .{});
        defer allocator.free(temp_out_path);
        std.fs.cwd().deleteFile(temp_out_path) catch {};

        defer allocator.free(vvp_output);
    }

    const vcd_path = try std.fmt.allocPrint(allocator, "../{s}.vcd", .{test_name});
    defer allocator.free(vcd_path);
    std.fs.cwd().deleteFile(vcd_path) catch {};

    const cwd = try std.process.getCwdAlloc(allocator);

    const rel_path = "../temp";
    const abs_path = try std.fs.path.resolve(allocator, &[_][]const u8{ cwd, rel_path });

    try std.fs.deleteTreeAbsolute(abs_path);
}

fn generateTestbench(
    test_name: []const u8,
    wire_checks: []const WireCheck,
    allocator: std.mem.Allocator,
) ![]const u8 {
    var tb = std.ArrayList(u8).init(allocator);
    defer tb.deinit();

    try tb.writer().print(
        \\module {s}_tb;
        \\ reg clk;
        \\top dut (.clk(clk));
        \\initial begin
        \\ clk = 0;
        \\forever #1 clk = ~clk;
        \\end
        \\initial begin
        \\$dumpfile("{s}.vcd");
        \\$dumpvars(0, dut);
        \\end
        \\initial begin
        \\
    , .{
        test_name,
        test_name,
    });

    var sorted_checks = std.ArrayList(WireCheck).init(allocator);
    defer sorted_checks.deinit();

    try sorted_checks.appendSlice(wire_checks);

    const Context = struct {
        pub fn lessThan(_: @This(), lhs: WireCheck, rhs: WireCheck) bool {
            return lhs.tick < rhs.tick;
        }
    };
    std.sort.insertion(WireCheck, sorted_checks.items, Context{}, Context.lessThan);

    var current_tick: u32 = 0;
    var first_check = true;

    for (sorted_checks.items) |check| {
        if (first_check or check.tick != current_tick) {
            if (!first_check) {
                try tb.appendSlice("\n");
            }

            try tb.writer().print("#{d};\n", .{check.tick});
            current_tick = check.tick;
            first_check = false;
        }

        try tb.writer().print(
            \\if (dut.{s} !== 32'd{d}) begin
            \\  $error("Alu {s} got wrong value: got %d, expected {d}",
            \\   dut.{s});
            \\  $fatal(1, "Test failed");
            \\end
            \\
        , .{
            check.wire,
            check.value,
            check.wire,
            check.value,
            check.wire,
        });
    }

    try tb.writer().print(
        \\$finish;
        \\end
        \\endmodule
        \\
    , .{});

    return tb.toOwnedSlice();
}
