const std = @import("std");
const clay = @import("zclay");

pub const Role = enum {
    text,
    button,
    checkbox,
    switch_control,
    slider,
    text_field,
    navigation,
    navigation_item,
    dialog,
    progress_bar,
    status,
    group,
    list,
    tree,
    tree_item,
    radio_group,
    radio_button,
    combo_box,
    option,
    tab_list,
    tab,
    menu,
    menu_item,
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
    expanded: ?bool = null,
    level: u16 = 0,
    scrollable: bool = false,
    can_scroll_forward: bool = false,
    can_scroll_backward: bool = false,
    bounds: Bounds = .{},
};

pub const Bounds = struct {
    x: f32 = 0,
    y: f32 = 0,
    width: f32 = 0,
    height: f32 = 0,
};

pub const max_nodes = 96;

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

    /// Resolves the final Clay layout after `endLayout()`. Nodes whose Clay
    /// element was clipped or not emitted retain an empty rectangle and are
    /// ignored by native accessibility bridges.
    pub fn resolveBounds(self: *Registry) void {
        for (self.nodes[0..self.count]) |*node| {
            var element_id = clay.ElementId.ID("");
            element_id.id = node.element_id;
            const data = clay.getElementData(element_id);
            node.bounds = if (data.found) .{
                .x = data.bounding_box.x,
                .y = data.bounding_box.y,
                .width = data.bounding_box.width,
                .height = data.bounding_box.height,
            } else .{};
            if (node.scrollable) {
                const scroll = clay.getScrollContainerData(element_id);
                if (scroll.found and scroll.config.vertical) {
                    const max_scroll = @max(
                        scroll.content_dimensions.h - scroll.scroll_container_dimensions.h,
                        0,
                    );
                    node.can_scroll_forward = scroll.scroll_position.y > -max_scroll + 0.5;
                    node.can_scroll_backward = scroll.scroll_position.y < -0.5;
                } else {
                    node.can_scroll_forward = false;
                    node.can_scroll_backward = false;
                }
            }
        }
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

test "semantic registry retains the full fixed-capacity snapshot" {
    var registry: Registry = .{};
    for (0..max_nodes) |index| {
        try std.testing.expect(registry.add(.{
            .element_id = @intCast(index + 1),
            .role = .text,
            .label = "Node",
        }));
    }
    try std.testing.expectEqual(max_nodes, registry.items().len);
    try std.testing.expect(!registry.add(.{
        .element_id = max_nodes + 1,
        .role = .text,
        .label = "Overflow",
    }));
}
