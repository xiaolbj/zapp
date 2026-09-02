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
    list_item,
    table,
    row,
    column_header,
    chip,
};

/// Platform-neutral accessibility metadata emitted alongside a UI frame.
/// Platform bridges use `element_id` to associate a semantic node with Clay layout data.
pub const Node = struct {
    pub const max_scroll_ancestors = 4;

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
    required: bool = false,
    invalid: bool = false,
    error_text: []const u8 = "",
    expanded: ?bool = null,
    level: u16 = 0,
    row_index: u16 = 0,
    column_index: u16 = 0,
    row_span: u16 = 1,
    column_span: u16 = 1,
    row_count: u16 = 0,
    column_count: u16 = 0,
    scrollable: bool = false,
    can_scroll_forward: bool = false,
    can_scroll_backward: bool = false,
    bounds: Bounds = .{},
    scroll_ancestor_ids: [max_scroll_ancestors]u32 = @splat(0),
    scroll_ancestor_count: usize = 0,
};

pub const Bounds = struct {
    x: f32 = 0,
    y: f32 = 0,
    width: f32 = 0,
    height: f32 = 0,
};

pub const max_nodes = 128;

pub const Registry = struct {
    nodes: [max_nodes]Node = undefined,
    count: usize = 0,
    scroll_ancestor_ids: [Node.max_scroll_ancestors]u32 = @splat(0),
    scroll_ancestor_count: usize = 0,

    pub fn reset(self: *Registry) void {
        self.count = 0;
        self.scroll_ancestor_count = 0;
    }

    pub fn add(self: *Registry, node: Node) bool {
        if (self.count == self.nodes.len) return false;
        var resolved = node;
        resolved.scroll_ancestor_count = self.scroll_ancestor_count;
        @memcpy(
            resolved.scroll_ancestor_ids[0..self.scroll_ancestor_count],
            self.scroll_ancestor_ids[0..self.scroll_ancestor_count],
        );
        self.nodes[self.count] = resolved;
        self.count += 1;
        return true;
    }

    pub fn pushScrollAncestor(self: *Registry, element_id: u32) bool {
        if (self.scroll_ancestor_count == self.scroll_ancestor_ids.len) return false;
        self.scroll_ancestor_ids[self.scroll_ancestor_count] = element_id;
        self.scroll_ancestor_count += 1;
        return true;
    }

    pub fn popScrollAncestor(self: *Registry) void {
        if (self.scroll_ancestor_count > 0) self.scroll_ancestor_count -= 1;
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
            // Clay_GetElementData already includes every ancestor's childOffset
            // in both descendants and nested clip containers. Only intersect
            // those final boxes here; adding scrollPosition again would shift
            // accessibility hit targets twice after scrolling.
            var clip_bounds: [Node.max_scroll_ancestors]Bounds = undefined;
            var clip_count: usize = 0;
            for (node.scroll_ancestor_ids[0..node.scroll_ancestor_count]) |ancestor_value| {
                var ancestor_id = clay.ElementId.ID("");
                ancestor_id.id = ancestor_value;
                const ancestor_data = clay.getElementData(ancestor_id);
                if (ancestor_data.found) {
                    clip_bounds[clip_count] = .{
                        .x = ancestor_data.bounding_box.x,
                        .y = ancestor_data.bounding_box.y,
                        .width = ancestor_data.bounding_box.width,
                        .height = ancestor_data.bounding_box.height,
                    };
                    clip_count += 1;
                }
            }
            for (clip_bounds[0..clip_count]) |clip| {
                node.bounds = intersectBounds(node.bounds, clip) orelse .{};
            }
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

fn intersectBounds(a: Bounds, b: Bounds) ?Bounds {
    const left = @max(a.x, b.x);
    const top = @max(a.y, b.y);
    const right = @min(a.x + a.width, b.x + b.width);
    const bottom = @min(a.y + a.height, b.y + b.height);
    if (right <= left or bottom <= top) return null;
    return .{ .x = left, .y = top, .width = right - left, .height = bottom - top };
}

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

test "semantic registry snapshots nested scroll ancestors" {
    var registry: Registry = .{};
    try std.testing.expect(registry.pushScrollAncestor(10));
    try std.testing.expect(registry.pushScrollAncestor(20));
    try std.testing.expect(registry.add(.{ .element_id = 1, .role = .text, .label = "Row" }));
    try std.testing.expectEqual(@as(usize, 2), registry.items()[0].scroll_ancestor_count);
    try std.testing.expectEqual(@as(u32, 10), registry.items()[0].scroll_ancestor_ids[0]);
    try std.testing.expectEqual(@as(u32, 20), registry.items()[0].scroll_ancestor_ids[1]);
    registry.popScrollAncestor();
    registry.reset();
    try std.testing.expectEqual(@as(usize, 0), registry.scroll_ancestor_count);
}

test "bounds intersection clips partially visible rows" {
    const clipped = intersectBounds(
        .{ .x = 10, .y = 90, .width = 50, .height = 30 },
        .{ .x = 0, .y = 0, .width = 100, .height = 100 },
    ).?;
    try std.testing.expectEqual(@as(f32, 10), clipped.height);
    try std.testing.expect(intersectBounds(
        .{ .x = 10, .y = 120, .width = 50, .height = 30 },
        .{ .x = 0, .y = 0, .width = 100, .height = 100 },
    ) == null);
}
