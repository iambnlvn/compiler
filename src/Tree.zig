const std = @import("std");
const eql = std.mem.eql;

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
