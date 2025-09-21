const std = @import("std");
const asm_ast = @import("../ast/asm.zig");

pub const Emitter = struct {
    program: asm_ast.Program,

    pub fn init(program: asm_ast.Program) Emitter {
        return .{ .program = program };
    }

    fn reg_to_string() []const u8 {}

    pub fn getAssemblyString(self: Emitter, allocator: std.mem.Allocator) ![]const u8 {
        var buffer = std.ArrayList(u8).init(allocator);
        errdefer buffer.deinit();
        const writer = buffer.writer();

        for (self.program.function.instructions) |instruction| {
            switch (instruction) {
                .rtype => |r| {
                    try std.fmt.format(writer, "{s} {s} {s} {s}\n", .{
                        r.instr.toString(),
                        r.destination.toString(),
                        r.source1.toString(),
                        r.source2.toString(),
                    });
                },
                .itype => |i| {
                    switch (i.instr) {
                        .LW, .LH, .LB, .LHU, .LBU => {
                            try std.fmt.format(writer, "{s} {s} {}({s})\n", .{
                                i.instr.toString(),
                                i.destination.toString(),
                                i.immediate,
                                i.source.toString(),
                            });
                        },
                        else => {
                            try std.fmt.format(writer, "{s} {s} {s} {}\n", .{
                                i.instr.toString(),
                                i.destination.toString(),
                                i.source.toString(),
                                i.immediate,
                            });
                        },
                    }
                },
                .btype => |b| {
                    try std.fmt.format(writer, "{s} {s} {s} {s}\n", .{
                        b.instr.toString(),
                        b.source1.toString(),
                        b.source2.toString(),
                        b.label,
                    });
                },
                .stype => |s| {
                    try std.fmt.format(writer, "{s} {s} {}({s})\n", .{
                        s.instr.toString(),
                        s.source1.toString(),
                        s.immediate,
                        s.source2.toString(),
                    });
                },
                .jtype => |j| {
                    try std.fmt.format(writer, "{s} {s} {s}\n", .{
                        j.instr.toString(),
                        j.destination.toString(),
                        j.label,
                    });
                },
                .utype => |u| {
                    try std.fmt.format(writer, "{s} {s} {}\n", .{
                        u.instr.toString(),
                        u.destination.toString(),
                        u.immediate,
                    });
                },
                .label => |label| {
                    try std.fmt.format(writer, "{s}:\n", .{
                        label.name,
                    });
                },
            }
        }

        return buffer.toOwnedSlice(); // Caller owns the memory
    }

    pub fn write(self: Emitter, out_name: []const u8, allocator: std.mem.Allocator) !void {
        const dirname = std.fs.path.dirname(out_name) orelse ".";
        const stem = std.fs.path.stem(out_name);

        var path_buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
        const output_path = try std.fmt.bufPrint(&path_buf, "{s}/{s}.asm", .{
            dirname,
            stem,
        });

        const assembly = try self.getAssemblyString(allocator);
        defer allocator.free(assembly);

        const file = try std.fs.cwd().createFile(
            output_path,
            .{},
        );
        defer file.close();

        try file.writeAll(assembly);
    }
};
