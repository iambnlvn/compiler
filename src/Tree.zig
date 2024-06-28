const std = @import("std");
const eql = std.mem.eql;
const print = std.debug.print;
const startsWith = std.mem.startsWith;
const endsWith = std.mem.endsWith;
const Allocator = std.mem.Allocator;

const CompileError = error{
    IncorrectExpression,
};
pub const Node = struct {
    const NodeType = enum { OP, Var, Const };

    val: []const u8,
    nodeType: NodeType,
    parent: ?(*Node),
    right: ?(*Node),
    left: ?(*Node),
    nodeLevel: usize,

    fn init(token: []const u8, nodeLevel: usize, vars: *std.StringHashMap(bool)) Node {
        return Node{
            .val = token,
            .nodeType = getType(token, vars),
            .parent = null,
            .right = null,
            .left = null,
            .nodeLevel = nodeLevel,
        };
    }

    fn getType(token: []const u8, vars: *std.StringHashMap(bool)) NodeType {
        if (token.len == 1) switch (token[0]) {
            inline '+', '-', '*', '/', '%', '<', '>', '&', '|', '^' => return NodeType.OP,
            else => {},
        } else if (eql(u8, "==", token) or (eql(u8, "!=", token)) or (eql(u8, "<", token)) or (eql(u8, ">", token)) or (eql(u8, "<=", token)) or (eql(u8, ">=", token))) {
            return NodeType.OP;
        }

        if (vars.contains(token)) {
            return NodeType.Var;
        } else {
            return NodeType.Const;
        }
    }
};

pub fn Tree(comptime T: type) type {
    return struct {
        const Self = @This();
        tree: std.ArrayList(Node),
        root: ?(*Node),
        allocator: Allocator,
        output: std.ArrayList([]const u8),
        pub fn init(allocator: Allocator) Self {
            return Self{
                .tree = std.ArrayList(Node).init(allocator),
                .root = null,
                .allocator = allocator,
                .output = std.ArrayList([]const u8).init(allocator),
            };
        }

        pub fn deinit(self: *Self) void {
            self.tree.deinit();
            self.output.deinit();
        }

        fn shouldReparentNodes(prevNode: *Node, newNode: *Node) bool {
            return prevNode.nodeLevel > newNode.nodeLevel or (prevNode.nodeLevel == newNode.nodeLevel and !(!(eql(u8, prevNode.val, "*") or eql(u8, prevNode.val, "/") or eql(u8, prevNode.val, "%") or eql(u8, prevNode.val, "&")) and (eql(u8, newNode.val, "*") or eql(u8, newNode.val, "/") or eql(u8, newNode.val, "%") or eql(u8, newNode.val, "&"))));
        }

        fn reparentNode(prevNode: *Node, newNode: *Node, tree: *Self) void {
            if (prevNode.parent) |parent| {
                prevNode.parent = newNode;
                parent.right = newNode;
                newNode.parent = parent;
                newNode.right = prevNode;
            } else {
                tree.root = newNode;
                newNode.right = prevNode;
                prevNode.parent = newNode;
            }
        }
        pub fn buildTree(self: *Self, tokens: *std.mem.TokenIterator(u8, .any), vars: *std.StringHashMap(bool)) !void {
            var tree = &self.tree;
            var nodeLevel: usize = 0;

            while (tokens.next()) |v| {
                if (std.mem.startsWith(u8, v, "(")) {
                    nodeLevel += 1;
                }

                var newTokens = std.mem.tokenizeAny(u8, v, "()");

                while (newTokens.next()) |token| {
                    const currentNode = Node.init(token, nodeLevel, vars);
                    const len = tree.items.len;
                    try tree.append(currentNode);

                    if (len == 0) {
                        continue;
                    }

                    var prevNode = &tree.items[len - 1];
                    const newNode = &tree.items[len];

                    if (len == 1) {
                        self.root = newNode;
                        newNode.right = prevNode;
                        prevNode.parent = newNode;
                        continue;
                    }
                    if (((newNode.nodeType == .Const or newNode.nodeType == .Var) and
                        (prevNode.nodeType == .Const or prevNode.nodeType == .Var)) or
                        newNode.nodeType == prevNode.nodeType)
                    {
                        return CompileError.IncorrectExpression;
                    }
                    if (prevNode.nodeType == .OP) {
                        prevNode.left = prevNode.right;
                        prevNode.right = newNode;
                        newNode.parent = prevNode;
                    } else {
                        while (prevNode.nodeLevel > newNode.nodeLevel) {
                            if (prevNode.parent) |parent| {
                                prevNode = parent;
                            } else {
                                break;
                            }
                        }
                        if (prevNode.nodeType != .OP) {
                            prevNode = prevNode.parent.?;
                        }
                        if (shouldReparentNodes(prevNode, newNode)) {
                            reparentNode(prevNode, newNode, self);
                        } else {
                            prevNode.right.?.parent = newNode;
                            newNode.right = prevNode.right;
                            prevNode.right = newNode;
                            newNode.parent = prevNode;
                        }
                    }
                }
                if (endsWith(u8, v, ")")) {
                    nodeLevel -= 1;
                }
            }
        }
        fn count(str: T) usize {
            const counter = 0;
            for (str) |char| {
                if (eql(u8, char, " ") or eql(u8, char, "(") or eql(u8, char, ")")) {
                    count += 1;
                }
            }
            return counter;
        }

        pub fn printTree(self: *Self) void {
            for (self.tree.items) |node| {
                if (node.parent) |parent| {
                    print("Parent '{s}'\n", .{parent.val});
                }
                print("node = '{s}'\n nodeType = '{any}'\nNodeLevel = '{d}'\n", .{ node.val, node.nodeType, node.nodeLevel });
                if (node.left) |l| {
                    print("Left = '{s}'\n", .{l.val});
                }
                if (node.right) |r| {
                    print("Right = '{s}'\n", .{r.val});
                }
            }
        }
    };
}
