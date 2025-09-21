const std = @import("std");
const c_ast = @import("../ast/c.zig");
const IdentifierResolution = @import("semantic/identifier-resolution.zig").IdentifierResolution;
const LoopLabeling = @import("semantic/loop-labeling.zig").LoopLabeling;
const TypeChecking = @import("semantic/type-checking.zig").TypeChecking;
const testing = @import("../testing.zig");

pub const SemanticAnalysis = struct {
    allocator: std.mem.Allocator,
    pub fn init(allocator: std.mem.Allocator) SemanticAnalysis {
        return .{ .allocator = allocator };
    }

    pub fn analyze(self: *SemanticAnalysis, program: c_ast.Program) !c_ast.Program {
        var variable_resolution = IdentifierResolution.init(self.allocator);
        var loop_labeling = LoopLabeling.init(self.allocator);
        var type_checking = TypeChecking.init(self.allocator);

        return try type_checking.check(try loop_labeling.label(try variable_resolution.resolve(program)));
    }
};

test "function parameter duplicate definition" {
    const input =
        \\int main()
        \\{
        \\ int foo(int a, int a);
        \\}
        \\
    ;

    const result = testing.cToSemanticAnalysis(input);
    try testing.expectError(error.DuplicateDefinition, result);
}

test "incompatible declarations" {
    const input =
        \\int main() {
        \\    int foo(int a);
        \\    return foo(1);
        \\}
        \\
        \\int foo(int a, int b);
    ;

    const result = testing.cToSemanticAnalysis(input);
    try testing.expectError(error.IncompatibleFunctionDeclarations, result);
}

test "variable used as function" {
    const input =
        \\int main()
        \\{
        \\    int x = 3;
        \\    return x();
        \\}
    ;

    const result = testing.cToSemanticAnalysis(input);
    try testing.expectError(error.VariableUsedAsFunction, result);
}

test "function already defined" {
    const input =
        \\int x(int a) {
        \\    return a;
        \\}
        \\
        \\int x(int a) {
        \\    return a;
        \\}
        \\
        \\int main()
        \\{
        \\    return x();
        \\}
    ;

    const result = testing.cToSemanticAnalysis(input);
    try testing.expectError(error.FunctionAlreadyDefined, result);
}
