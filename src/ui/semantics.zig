const std = @import("std");

pub const Role = enum {
    button,
    checkbox,
    switch_control,
    slider,
    text_field,
    navigation,
    navigation_item,
    dialog,
};

/// Platform-neutral accessibility metadata emitted alongside a UI frame.
/// Platform bridges use `element_id` to associate a semantic node with Clay layout data.
pub const Node = struct {
    element_id: u32,
    role: Role,
    label: []const u8,
    value_text: []const u8 = "",
    value: ?f32 = null,
    checked: ?bool = null,
    disabled: bool = false,
    focused: bool = false,
    selected: bool = false,
    modal: bool = false,
};

pub const max_nodes = 64;

pub const Registry = struct {
    nodes: [max_nodes]Node = undefined,
    count: usize = 0,

    pub fn reset(self: *Registry) void {
        self.count = 0;
    }

    pub fn add(self: *Registry, node: Node) bool {
        if (self.count == self.nodes.len) return false;
        self.nodes[self.count] = node;
        self.count += 1;
        return true;
    }

    pub fn items(self: *const Registry) []const Node {
        return self.nodes[0..self.count];
    }
};

test "semantic registry resets without retaining frame nodes" {
    var registry: Registry = .{};
    try std.testing.expect(registry.add(.{
        .element_id = 7,
        .role = .button,
        .label = "Save",
        .focused = true,
    }));
    try std.testing.expectEqual(@as(usize, 1), registry.items().len);
    try std.testing.expect(registry.items()[0].focused);
    registry.reset();
    try std.testing.expectEqual(@as(usize, 0), registry.items().len);
}
