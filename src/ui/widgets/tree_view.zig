const std = @import("std");
const clay = @import("zclay");
const interaction = @import("interaction.zig");
const label = @import("label.zig");
const semantics = @import("../semantics.zig");
const theme = @import("../theme.zig");

pub const Item = struct {
    text: []const u8,
    parent_index: ?usize = null,
};

pub const Config = struct {
    id: []const u8,
    items: []const Item,
    expanded_mask: u64,
    selected_index: ?usize = null,
    focused_id: ?u32 = null,
    width: f32 = 320,
    disabled: bool = false,
    semantic_label: []const u8 = "Tree",
    semantic_registry: ?*semantics.Registry = null,
};

pub const Result = struct {
    selected_index: ?usize = null,
    toggled_index: ?usize = null,
    focus_index: ?usize = null,
};

const row_height: f32 = 36;
const indent_width: f32 = 20;

/// Draws a controlled tree. Parents must appear before their children and the
/// expansion mask uses each item's array index as its bit position.
pub fn draw(state: *interaction.State, input: interaction.Input, config: Config) Result {
    var output: Result = .{};
    const tree_id = clay.ElementId.IDI(config.id, std.math.maxInt(i32));
    if (config.semantic_registry) |registry| _ = registry.add(.{
        .element_id = tree_id.id,
        .role = .tree,
        .label = config.semantic_label,
        .disabled = config.disabled,
    });

    clay.UI()(.{
        .id = tree_id,
        .layout = .{
            .sizing = .{ .w = .fixed(config.width), .h = .fit },
            .child_gap = theme.controls.gap_tiny,
            .direction = .top_to_bottom,
        },
    })({
        for (config.items, 0..) |item, index| {
            if (!isVisible(config.items, index, config.expanded_mask)) continue;
            const id = itemId(config.id, index);
            const focused = config.focused_id == id.id;
            const selected = config.selected_index == index;
            const child_count = hasChildren(config.items, index);
            const expanded = child_count and isExpanded(config.expanded_mask, index);
            const pointer = interaction.update(state, id.id, clay.pointerOver(id), input, config.disabled);
            const depth = itemDepth(config.items, index);
            const background: clay.Color = if (config.disabled)
                theme.controls.input_disabled
            else if (pointer.active)
                theme.controls.accent_pressed
            else if (selected)
                theme.controls.navigation_active
            else if (pointer.hovered or focused)
                theme.controls.surface_hover
            else
                theme.controls.transparent;

            if (config.semantic_registry) |registry| _ = registry.add(.{
                .element_id = id.id,
                .role = .tree_item,
                .label = item.text,
                .disabled = config.disabled,
                .focused = focused,
                .selected = selected,
                .expanded = if (child_count) expanded else null,
                .level = @intCast(depth + 1),
            });

            clay.UI()(.{
                .id = id,
                .layout = .{
                    .sizing = .{ .w = .fixed(config.width), .h = .fixed(row_height) },
                    .padding = .{ .left = @intCast(10 + depth * @as(usize, @intFromFloat(indent_width))), .right = 10 },
                    .child_gap = theme.controls.gap_small,
                    .child_alignment = .{ .y = .center },
                },
                .background_color = background,
                .corner_radius = .all(theme.controls.radius_small),
                .border = .{
                    .color = theme.controls.focus,
                    .width = if (focused) .outside(theme.controls.focus_width) else .{},
                },
            })({
                label.draw(if (child_count) if (expanded) "-" else "+" else "·", .{
                    .font_size = 16,
                    .color = if (config.disabled) theme.controls.text_disabled else theme.controls.text_muted,
                });
                label.draw(item.text, .{
                    .font_size = 15,
                    .color = if (config.disabled) theme.controls.text_disabled else theme.controls.text_secondary,
                });
            });

            if (pointer.clicked) {
                output.focus_index = index;
                const data = clay.getElementData(id);
                const toggle_limit = if (data.found)
                    data.bounding_box.x + 38 + @as(f32, @floatFromInt(depth)) * indent_width
                else
                    -1;
                if (child_count and input.x <= toggle_limit) {
                    output.toggled_index = index;
                } else {
                    output.selected_index = index;
                }
            }
            if (!config.disabled and focused) {
                if (input.activate_pressed) output.selected_index = index;
                if (input.up_pressed) {
                    output.focus_index = visibleNeighbor(config.items, index, config.expanded_mask, -1);
                } else if (input.down_pressed) {
                    output.focus_index = visibleNeighbor(config.items, index, config.expanded_mask, 1);
                } else if (input.right_pressed and child_count) {
                    if (!expanded) {
                        output.toggled_index = index;
                    } else if (firstChild(config.items, index)) |child| {
                        output.focus_index = child;
                    }
                } else if (input.left_pressed) {
                    if (expanded) {
                        output.toggled_index = index;
                    } else if (item.parent_index) |parent| {
                        output.focus_index = parent;
                    }
                }
            }
        }
    });
    return output;
}

pub fn itemId(tree_id: []const u8, index: usize) clay.ElementId {
    return clay.ElementId.IDI(tree_id, @intCast(index));
}

pub fn isVisible(items: []const Item, index: usize, expanded_mask: u64) bool {
    if (index >= items.len) return false;
    var parent = items[index].parent_index;
    var remaining = items.len;
    while (parent) |parent_index| {
        if (parent_index >= index or remaining == 0) return false;
        if (!isExpanded(expanded_mask, parent_index)) return false;
        parent = items[parent_index].parent_index;
        remaining -= 1;
    }
    return true;
}

/// Returns the adjacent visible item without wrapping at either end.
pub fn visibleNeighbor(items: []const Item, index: usize, expanded_mask: u64, direction: i8) ?usize {
    if (!isVisible(items, index, expanded_mask) or direction == 0) return null;
    if (direction < 0) {
        var candidate = index;
        while (candidate > 0) {
            candidate -= 1;
            if (isVisible(items, candidate, expanded_mask)) return candidate;
        }
        return null;
    }
    var candidate = index + 1;
    while (candidate < items.len) : (candidate += 1) {
        if (isVisible(items, candidate, expanded_mask)) return candidate;
    }
    return null;
}

/// Repairs focus after a parent collapses by returning the nearest visible
/// ancestor. A visible item is returned unchanged.
pub fn nearestVisibleAncestor(items: []const Item, index: usize, expanded_mask: u64) ?usize {
    if (index >= items.len) return null;
    var candidate = index;
    var remaining = items.len;
    while (!isVisible(items, candidate, expanded_mask)) {
        candidate = items[candidate].parent_index orelse return null;
        if (candidate >= items.len or remaining == 0) return null;
        remaining -= 1;
    }
    return candidate;
}

fn isExpanded(mask: u64, index: usize) bool {
    return index < 64 and mask & (@as(u64, 1) << @intCast(index)) != 0;
}

fn hasChildren(items: []const Item, index: usize) bool {
    return firstChild(items, index) != null;
}

fn firstChild(items: []const Item, index: usize) ?usize {
    for (items, 0..) |item, child_index| {
        if (item.parent_index == index) return child_index;
    }
    return null;
}

fn itemDepth(items: []const Item, index: usize) usize {
    var depth: usize = 0;
    var parent = items[index].parent_index;
    var remaining = items.len;
    while (parent) |parent_index| {
        if (parent_index >= index or remaining == 0) break;
        depth += 1;
        parent = items[parent_index].parent_index;
        remaining -= 1;
    }
    return depth;
}

test "collapsed ancestors hide descendants" {
    const items = [_]Item{
        .{ .text = "root" },
        .{ .text = "src", .parent_index = 0 },
        .{ .text = "ui", .parent_index = 1 },
        .{ .text = "readme", .parent_index = 0 },
    };
    try std.testing.expect(isVisible(&items, 0, 0));
    try std.testing.expect(!isVisible(&items, 1, 0));
    try std.testing.expect(isVisible(&items, 1, 1));
    try std.testing.expect(!isVisible(&items, 2, 1));
    try std.testing.expect(isVisible(&items, 2, 3));
}

test "tree helpers report hierarchy" {
    const items = [_]Item{
        .{ .text = "root" },
        .{ .text = "child", .parent_index = 0 },
    };
    try std.testing.expect(hasChildren(&items, 0));
    try std.testing.expectEqual(@as(?usize, 1), firstChild(&items, 0));
    try std.testing.expectEqual(@as(usize, 1), itemDepth(&items, 1));
}

test "visible neighbors skip collapsed descendants and do not wrap" {
    const items = [_]Item{
        .{ .text = "root" },
        .{ .text = "src", .parent_index = 0 },
        .{ .text = "ui", .parent_index = 1 },
        .{ .text = "readme", .parent_index = 0 },
    };

    try std.testing.expectEqual(@as(?usize, null), visibleNeighbor(&items, 0, 1, -1));
    try std.testing.expectEqual(@as(?usize, 1), visibleNeighbor(&items, 0, 1, 1));
    try std.testing.expectEqual(@as(?usize, 3), visibleNeighbor(&items, 1, 1, 1));
    try std.testing.expectEqual(@as(?usize, 2), visibleNeighbor(&items, 1, 3, 1));
    try std.testing.expectEqual(@as(?usize, null), visibleNeighbor(&items, 3, 3, 1));
}

test "collapsed tree focus returns to nearest visible ancestor" {
    const items = [_]Item{
        .{ .text = "root" },
        .{ .text = "src", .parent_index = 0 },
        .{ .text = "ui", .parent_index = 1 },
    };

    try std.testing.expectEqual(@as(?usize, 2), nearestVisibleAncestor(&items, 2, 3));
    try std.testing.expectEqual(@as(?usize, 1), nearestVisibleAncestor(&items, 2, 1));
    try std.testing.expectEqual(@as(?usize, 0), nearestVisibleAncestor(&items, 2, 0));
    try std.testing.expectEqual(@as(?usize, null), nearestVisibleAncestor(&items, 99, 3));
}
