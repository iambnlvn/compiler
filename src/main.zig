const std = @import("std");
const lib = @import("Tree.zig");
const eql = std.mem.eql;
const print = std.debug.print;
const CODE_PATH = "code.sigx";
const Allocator = std.mem.Allocator;
const delimiter: std.mem.DelimiterType = .any;

const CompileError = error{ SyntaxError, ShadowVariable, RuntimeError };

const r8 = "r8";
const r9 = "r9";

var START: usize = 0;
var labelCounter: usize = 1;
const varType = "dq"; //define quadword
var buf: [1024]u8 = undefined;
var fbs = std.io.fixedBufferStream(&buf);
const writer = fbs.writer();
var label_counter: u8 = 1;
const FLAG = enum { Loop, NonLoop };

const loopFlag = FLAG.NonLoop;
var loopLabel: []const u8 = undefined;

pub fn main() !void {
    const code = @embedFile(CODE_PATH);
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var lines = std.mem.tokenizeAny(u8, code, "\n");
    var vars = std.StringHashMap(bool).init(allocator);
    var out = std.ArrayList([]const u8).init(allocator);
    var data = std.ArrayList([]const u8).init(allocator);
    var normal = std.ArrayList([]const u8).init(allocator);
    var end = std.ArrayList([]const u8).init(allocator);
    var flags = std.ArrayList(FLAG).init(allocator);

    try out.append("global _start\n");
    try out.append("extern _print\n");
    try data.append("section .data\n");
    try normal.append("_start:\n");
    try bracketExpr(&lines, &normal, &data, &vars, &end, &flags, allocator);

    try concat(&out, &data);
    try out.append("section .text\n");
    try concat(&out, &normal);
    try out.append("exit:\nmov rax, 60\nsyscall\n");
    const cwd = std.fs.cwd();
    const outFile = try cwd.createFile("asm/gen.asm", .{});
    defer outFile.close();
    for (out.items) |value| {
        try outFile.writeAll(value);
    }
}

fn bracketExpr(lines: *std.mem.TokenIterator(u8, delimiter), normal: *std.ArrayList([]const u8), data: *std.ArrayList([]const u8), vars: *std.StringHashMap(bool), end: *std.ArrayList([]const u8), flags: *std.ArrayList(FLAG), allocator: Allocator) !void {
    while (lines.next()) |line| {
        var tokens = std.mem.tokenize(u8, line, " ");
        const first = tokens.next().?;
        var varName: []const u8 = undefined;

        if (eql(u8, first, "{")) {
            try end.append(":\n");
            try end.append(try currentLabel());
            try end.append("end");

            if (flags.pop() == .Loop) {
                try end.append("\n");
                try end.append(loopLabel);
                try end.append("loop");
                try end.append("jmp ");
            }

            try normal.append("start");
            try normal.append(try currentLabel());
            try normal.append(":\n");

            try bracketExpr(lines, normal, data, vars, end, flags, allocator);
        } else if (eql(u8, first, "}")) {
            for (0..7) |_| {
                try normal.append(end.pop());
            }
            labelCounter += 1;
            break;
        } else if (!eql(u8, first, "if") and !eql(u8, first, "while") and !eql(u8, first, "print")) {
            varName = first;
            _ = tokens.next().?; // Might be an err if no eq expr

            if (!vars.contains(varName)) {
                try vars.put(varName, true);

                try data.append(varName);
                try data.append(" ");
                try data.append(varType);
                try data.append(" 0\n");
            }

            try varExpr(varName, &tokens, normal, vars, allocator);
        } else if (eql(u8, first, "if")) {
            try flags.append(.NonLoop);
            try ifExpr(&tokens, normal, vars, allocator);
        } else if (eql(u8, first, "while")) {
            try flags.append(.Loop);

            try whileExpr(&tokens, normal, vars, allocator);
        } else if (eql(u8, first, "print")) {
            try printExpr(&tokens, normal, vars, allocator);
        } else {
            unreachable;
        }
    }
}

fn currentLabel() ![]const u8 {
    try writer.print("{d}", .{labelCounter});

    if (label_counter > 378) {
        return CompileError.RuntimeError;
    }

    const written = fbs.getWritten();
    const label = written[START..];
    START = written.len;

    return label;
}

fn isComplexExpr(tokens: *std.mem.TokenIterator(u8, delimiter)) bool {
    if (eql(u8, tokens.peek().?, tokens.rest())) {
        return false;
    } else {
        return true;
    }
}

fn varExpr(varName: []const u8, tokens: *std.mem.TokenIterator(u8, delimiter), block: *std.ArrayList([]const u8), vars: *std.StringHashMap(bool), allocator: Allocator) !void {
    if (isComplexExpr(tokens)) {
        try computeExpr(block, tokens, vars, allocator);

        try block.append("pop r8\n");
        try block.append("mov qword[");
        try block.append(varName);
        try block.append("], r8\n");
    } else {
        const varValue = tokens.next().?;

        if (vars.contains(varValue)) {
            try block.append("push qword[");
            try block.append(varValue);
            try block.append("]\n");
        } else {
            try block.append("push ");
            try block.append(varValue);
            try block.append("\n");
        }

        try block.append("pop qword[");
        try block.append(varName);
        try block.append("]\n");
    }
}

fn ifExpr(tokens: *std.mem.TokenIterator(u8, delimiter), block: *std.ArrayList([]const u8), vars: *std.StringHashMap(bool), allocator: Allocator) !void {
    try computeExpr(block, tokens, vars, allocator);

    try block.append("pop r8\ncmp r8, 0\njne start");
    try block.append(try currentLabel());
    try block.append("\njmp ");
    try block.append("end");
    try block.append(try currentLabel());
    try block.append("\n");
}

fn concat(out: *std.ArrayList([]const u8), in: *std.ArrayList([]const u8)) !void {
    for (in.items) |value| {
        try out.append(value);
    }
}
fn computeExpr(block: *std.ArrayList([]const u8), tokens: *std.mem.TokenIterator(u8, delimiter), vars: *std.StringHashMap(bool), allocator: Allocator) !void {
    var tree = lib.Tree([]const u8).init(allocator);
    defer tree.deinit();
    errdefer tree.printTree();

    try tree.buildTree(tokens, vars);

    try genOut(&tree);

    for (tree.output.items) |value| {
        try block.append(value);
    }
}
fn whileExpr(tokens: *std.mem.TokenIterator(u8, delimiter), block: *std.ArrayList([]const u8), vars: *std.StringHashMap(bool), allocator: Allocator) !void {
    try block.append("loop");
    try block.append(try currentLabel());
    try block.append(":\n");
    loopLabel = try currentLabel();

    try computeExpr(block, tokens, vars, allocator);

    try block.append("pop r8\ncmp r8, 0\njne start");
    try block.append(try currentLabel());
    try block.append("\njmp ");
    try block.append("end");
    try block.append(try currentLabel());
    try block.append("\n");
}
fn printExpr(tokens: *std.mem.TokenIterator(u8, delimiter), block: *std.ArrayList([]const u8), vars: *std.StringHashMap(bool), allocator: Allocator) !void {
    if (isComplexExpr(tokens)) {
        try computeExpr(block, tokens, vars, allocator);
    } else {
        try block.append("push ");

        const nxt = tokens.next().?;
        if (vars.contains(nxt)) {
            try block.append("qword[");
            try block.append(nxt);
            try block.append("]");
        } else {
            try block.append(nxt);
        }
        try block.append("\n");
    }

    try block.append("pop r15\ncall _print\n");
}
fn genOut(tree: *lib.Tree([]const u8)) !void {
    const root = tree.root.?;
    try pushNode(tree, root);
}

fn pushNode(self: *lib.Tree([]const u8), node: *lib.Node) !void {
    var str = &self.output;
    if (node.nodeType == .Var) {
        try str.append("push qword[");
        try str.append(node.val);
        try str.append("]\n");
    } else if (node.nodeType == .Const) {
        try str.append("push ");
        try str.append(node.val);
        try str.append("\n");
    } else {
        try pushNode(self, node.right.?);
        try pushNode(self, node.left.?);

        const operation = OperatorToAsm(node.val);

        if (eql(u8, operation, "idiv")) {
            try str.append("pop rax\ncqo\n");
        } else {
            try str.append("pop ");
            try str.append(r8);
            try str.append("\n");
        }

        try str.append("pop ");
        try str.append(r9);
        try str.append("\n");

        try str.append(operation);
        try str.append(" ");

        if (eql(u8, operation, "idiv")) {
            try str.append(r9);
            try str.append("\n");

            if (eql(u8, node.val, "%")) {
                try str.append("push rdx\n");
            } else if (eql(u8, node.val, "/")) {
                try str.append("push rax\n");
            }
        } else if (eql(u8, operation, "cmp")) {
            try str.append(r8);
            try str.append(", ");
            try str.append(r9);
            try str.append("\n");

            const jump = getJumpType(node.val);
            const currLabel = try currentLabel();
            try str.append(jump);
            try str.append(" pos");
            try str.append(currLabel);
            try str.append("\npush 0\njmp neg");
            try str.append(currLabel);
            try str.append("\npos");
            try str.append(currLabel);
            try str.append(":\npush 1\nneg");
            try str.append(currLabel);
            try str.append(":\n");

            labelCounter += 1;
        } else {
            try str.append(r8);
            try str.append(", ");
            try str.append(r9);
            try str.append("\n");

            try str.append("push ");
            try str.append(r8);
            try str.append("\n");
        }
    }
}

fn OperatorToAsm(op: []const u8) []const u8 {
    return if (op.len == 1) switch (op[0]) {
        '+' => "add",
        '-' => "sub",
        '*' => "imul",
        '=' => "mov",
        '|' => "or",
        '&' => "and",
        inline '>', '<' => "cmp",
        inline '%', '/' => "idiv",
        else => unreachable,
    } else if (eql(u8, ">=", op) or eql(u8, "<=", op) or eql(u8, "==", op) or eql(u8, "!=", op)) "cmp" else unreachable;
}

fn getJumpType(token: []const u8) []const u8 {
    if (eql(u8, token, ">")) {
        return "ja";
    } else if (eql(u8, token, "<")) {
        return "jl";
    } else if (eql(u8, token, "==")) {
        return "je";
    } else if (eql(u8, token, ">=")) {
        return "jge";
    } else if (eql(u8, token, "<=")) {
        return "jle";
    } else if (eql(u8, token, "!=")) {
        return "jne";
    }
    return "jmp";
}
