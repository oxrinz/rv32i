const std = @import("std");
const c_ast = @import("ast/c.zig");

pub fn printExpression(exp: c_ast.Expression, indent: usize) void {
    const spaces = " " ** 64;
    std.debug.print("{s}", .{spaces[0..indent]});
    switch (exp) {
        .constant => |c| {
            std.debug.print("Constant: {}\n", .{c});
        },
        .binary => |b| {
            const op = switch (b.operator) {
                .Add => "+",
                .Subtract => "-",
                .Multiply => "*",
                .Divide => "/",
                .Remainder => "%",
                .Bitwise_AND => "&",
                .Bitwise_OR => "|",
                .Bitwise_XOR => "^",
                .Left_Shift => "<<",
                .Right_Shift => ">>",
                .Less => "<",
                .Less_Or_Equal => "<=",
                .Greater => ">",
                .Greater_Or_Equal => ">=",
                .Equal => "==",
                .Not_Equal => "!=",
                .And => "&&",
                .Or => "||",
            };
            std.debug.print("Binary Op: {s}\n", .{op});
            printExpression(b.left.*, indent + 4);
            printExpression(b.right.*, indent + 4);
        },
        .variable => |v| {
            std.debug.print("Variable: {s}\n", .{v.identifier});
        },
        .assignment => |a| {
            std.debug.print("Assignment:\n", .{});
            printExpression(a.left.*, indent + 4);
            printExpression(a.right.*, indent + 4);
        },
        .function_call => |fc| {
            std.debug.print("Function Call: {s}()\n", .{fc.identifier});
            for (fc.args) |arg| {
                printExpression(arg.*, indent + 4);
            }
        },
    }
}

pub fn printStatement(stmt: c_ast.Statement, indent: usize) void {
    const spaces = " " ** 64;
    std.debug.print("{s}", .{spaces[0..indent]});
    switch (stmt) {
        .ret => {
            std.debug.print("RETURN\n", .{});
            printExpression(stmt.ret.exp, indent + 2);
        },
        .exp => |expression| {
            printExpression(expression, indent);
        },
        .if_ => {
            std.debug.print("If\n", .{});
            printExpression(stmt.if_.condition, indent + 2);
            std.debug.print("{s}Then\n", .{spaces[0..indent]});
            printStatement(stmt.if_.then.*, indent + 2);
            if (stmt.if_.else_ != null) {
                std.debug.print("{s}Else\n", .{spaces[0..indent]});
                printStatement(stmt.if_.else_.?.*, indent + 2);
            }
        },
        .compound => {
            std.debug.print("Compound body:\n", .{});
            for (stmt.compound.block_items) |item| {
                printBlockItem(item, indent + 2);
            }
        },
        .while_ => {
            std.debug.print("While", .{});
            if (stmt.while_.identifier) |id| {
                std.debug.print(" ({s})", .{id});
            }
            std.debug.print("\n", .{});
            printExpression(stmt.while_.condition, indent + 2);
            std.debug.print("{s}Body\n", .{spaces[0..indent]});
            printStatement(stmt.while_.body.*, indent + 2);
        },
        .do_while => {
            std.debug.print("DoWhile", .{});
            if (stmt.do_while.identifier) |id| {
                std.debug.print(" ({s})", .{id});
            }
            std.debug.print("\n", .{});
            printStatement(stmt.do_while.body.*, indent + 2);
            std.debug.print("{s}While\n", .{spaces[0..indent]});
            printExpression(stmt.do_while.condition, indent + 2);
        },
        .for_ => {
            std.debug.print("For", .{});
            if (stmt.for_.identifier) |id| {
                std.debug.print(" ({s})", .{id});
            }
            std.debug.print("\n", .{});
            std.debug.print("{s}Init:\n", .{spaces[0 .. indent + 2]});
            switch (stmt.for_.init) {
                .init_exp => |init_exp| {
                    printExpression(init_exp.?, indent + 4);
                },
                .init_decl => |init_decl| {
                    printDeclaration(.{ .variable_declaration = init_decl }, indent + 4);
                },
            }
            std.debug.print("{s}Condition:\n", .{spaces[0 .. indent + 2]});
            if (stmt.for_.condition) |condition| {
                printExpression(condition, indent + 4);
            } else {
                std.debug.print("{s}(none)\n", .{spaces[0 .. indent + 4]});
            }
            std.debug.print("{s}Post:\n", .{spaces[0 .. indent + 2]});
            if (stmt.for_.post) |post| {
                printExpression(post, indent + 4);
            } else {
                std.debug.print("{s}(none)\n", .{spaces[0 .. indent + 4]});
            }
            std.debug.print("{s}Body:\n", .{spaces[0 .. indent + 2]});
            printStatement(stmt.for_.body.*, indent + 4);
        },
        .break_ => {
            std.debug.print("Break", .{});
            if (stmt.break_.identifier) |id| {
                std.debug.print(" ({s})", .{id});
            }
            std.debug.print("\n", .{});
        },
        .continue_ => {
            std.debug.print("Continue", .{});
            if (stmt.continue_.identifier) |id| {
                std.debug.print(" ({s})", .{id});
            }
            std.debug.print("\n", .{});
        },
    }
}

pub fn printDeclaration(decl: c_ast.Declaration, indent: usize) void {
    const spaces = " " ** 64;
    switch (decl) {
        .variable_declaration => |var_decl| {
            std.debug.print("{s}Declaration: {s}\n", .{ spaces[0..indent], var_decl.identifier });
            if (var_decl.initial) |initial| {
                printExpression(initial, indent + 2);
            }
        },
        .function_declaration => |func_decl| {
            printFunction(func_decl, indent);
        },
    }
}

pub fn printBlockItem(item: c_ast.BlockItem, indent: usize) void {
    switch (item) {
        .statement => |stmt| printStatement(stmt, indent),
        .declaration => |decl| printDeclaration(decl, indent),
    }
}

pub fn printFunction(func: c_ast.FunctionDeclaration, indent: usize) void {
    const spaces = " " ** 64;
    std.debug.print("{s}Function: {s}\n", .{ spaces[0..indent], func.identifier });

    // Print parameters
    if (func.params.len > 0) {
        std.debug.print("{s}Parameters:\n", .{spaces[0..indent]});
        for (func.params) |param| {
            std.debug.print("{s}{s}\n", .{ spaces[0 .. indent + 2], param });
        }
    }

    // Print body if it exists
    if (func.body) |body| {
        std.debug.print("{s}Body:\n", .{spaces[0..indent]});
        for (body.block_items) |item| {
            printBlockItem(item, indent + 2);
        }
    }
}

pub fn printProgram(program: c_ast.Program) void {
    std.debug.print("Program:\n", .{});
    for (program.function) |function| {
        printFunction(function, 2);
    }
}
