const std = @import("std");
const clay = @import("zclay");
const interaction = @import("interaction.zig");
const label = @import("label.zig");
const semantics = @import("../semantics.zig");
const theme = @import("../theme.zig");

pub const Item = struct {
    text: []const u8,
    disabled: bool = false,
};

pub const Config = struct {
    id: []const u8,
    items: []const Item,
    selected_mask: u64,
    direction: clay.LayoutDirection = .left_to_right,
    focused_id: ?u32 = null,
    disabled: bool = false,
    semantic_label: []const u8 = "Filters",
    semantic_registry: ?*semantics.Registry = null,
};

pub const Result = struct {
    toggled_index: ?usize = null,
    focus_index: ?usize = null,
};

pub const max_items = 64;

/// Draws a controlled multi-select set of compact filter chips. Selection is
/// reported as an index while the caller owns and updates the bit mask.
pub fn draw(state: *interaction.State, input: interaction.Input, config: Config) Result {
    var output: Result = .{};
    const items = config.items[0..@min(config.items.len, max_items)];
    const group_id = containerId(config.id);
    if (config.semantic_registry) |registry| _ = registry.add(.{
        .element_id = group_id.id,
        .role = .group,
        .label = config.semantic_label,
        .disabled = config.disabled,
    });

    clay.UI()(.{
        .id = group_id,
        .layout = .{
            .sizing = .fit,
            .child_gap = theme.controls.gap_small,
            .direction = config.direction,
        },
    })({
        for (items, 0..) |item, index| {
            const id = itemId(config.id, index);
            const item_disabled = config.disabled or item.disabled;
            const selected = isSelected(config.selected_mask, index);
            const focused = config.focused_id == id.id;
            const pointer = interaction.update(state, id.id, clay.pointerOver(id), input, item_disabled);
            if (config.semantic_registry) |registry| _ = registry.add(.{
                .element_id = id.id,
                .role = .chip,
                .label = item.text,
                .checked = selected,
                .selected = selected,
                .disabled = item_disabled,
                .focused = focused,
            });

            const background: clay.Color = if (item_disabled)
                theme.controls.surface_disabled_soft
            else if (selected)
                if (pointer.active) theme.controls.accent_pressed else theme.controls.accent
            else if (pointer.active)
                theme.controls.surface_focused
            else if (pointer.hovered or focused)
                theme.controls.surface_hover
            else
                theme.controls.surface;
            const text_color: clay.Color = if (item_disabled)
                theme.controls.text_disabled
            else if (selected)
                theme.controls.on_accent
            else
                theme.controls.text_secondary;

            clay.UI()(.{
                .id = id,
                .layout = .{
                    .sizing = .{ .w = .fit, .h = .fixed(36) },
                    .padding = .axes(12, 6),
                    .child_gap = theme.controls.gap_small,
                    .child_alignment = .center,
                },
                .background_color = background,
                .corner_radius = .all(18),
                .border = .{
                    .color = if (focused) theme.controls.focus else theme.controls.control_inactive,
                    .width = if (focused)
                        .outside(theme.controls.focus_width)
                    else if (!selected)
                        .outside(1)
                    else
                        .{},
                },
            })({
                if (selected) label.draw("✓", .{ .font_size = 14, .color = text_color });
                label.draw(item.text, .{ .font_size = 14, .color = text_color });
            });

            if (pointer.clicked) {
                output.focus_index = index;
                output.toggled_index = index;
            } else if (!item_disabled and focused) {
                if (input.activate_pressed) output.toggled_index = index;
                if (input.home_pressed) {
                    output.focus_index = firstEnabled(items);
                } else if (input.end_pressed) {
                    output.focus_index = lastEnabled(items);
                } else {
                    const previous = input.left_pressed or input.up_pressed;
                    const next = input.right_pressed or input.down_pressed;
                    if (previous != next) {
                        output.focus_index = adjacentEnabled(
                            items,
                            index,
                            if (previous) -1 else 1,
                        );
                    }
                }
            }
        }
    });
    return output;
}

pub fn containerId(group_id: []const u8) clay.ElementId {
    return clay.ElementId.IDI(group_id, std.math.maxInt(u32));
}

pub fn itemId(group_id: []const u8, index: usize) clay.ElementId {
    return clay.ElementId.IDI(group_id, @intCast(index));
}

pub fn isSelected(mask: u64, index: usize) bool {
    return index < 64 and mask & (@as(u64, 1) << @intCast(index)) != 0;
}

fn firstEnabled(items: []const Item) ?usize {
    for (items, 0..) |item, index| if (!item.disabled) return index;
    return null;
}

fn lastEnabled(items: []const Item) ?usize {
    var index = items.len;
    while (index > 0) {
        index -= 1;
        if (!items[index].disabled) return index;
    }
    return null;
}

fn adjacentEnabled(items: []const Item, current: usize, direction: i8) ?usize {
    if (items.len == 0 or firstEnabled(items) == null) return null;
    var index = @min(current, items.len - 1);
    for (0..items.len) |_| {
        index = if (direction < 0)
            if (index == 0) items.len - 1 else index - 1
        else
            (index + 1) % items.len;
        if (!items[index].disabled) return index;
    }
    return null;
}

test "chip group ids are stable and selection is bounded" {
    try std.testing.expect(containerId("StatusFilters").id != itemId("StatusFilters", 0).id);
    try std.testing.expect(isSelected(0b0101, 0));
    try std.testing.expect(!isSelected(0b0101, 1));
    try std.testing.expect(!isSelected(std.math.maxInt(u64), 64));
}

test "chip keyboard navigation wraps and skips disabled items" {
    const items = [_]Item{
        .{ .text = "All" },
        .{ .text = "Disabled", .disabled = true },
        .{ .text = "Open" },
        .{ .text = "Done" },
    };
    try std.testing.expectEqual(@as(?usize, 2), adjacentEnabled(&items, 0, 1));
    try std.testing.expectEqual(@as(?usize, 0), adjacentEnabled(&items, 2, -1));
    try std.testing.expectEqual(@as(?usize, 3), adjacentEnabled(&items, 0, -1));
    try std.testing.expectEqual(@as(?usize, 0), firstEnabled(&items));
    try std.testing.expectEqual(@as(?usize, 3), lastEnabled(&items));
}

test "chip navigation handles empty and fully disabled groups" {
    const empty = [_]Item{};
    const disabled = [_]Item{
        .{ .text = "A", .disabled = true },
        .{ .text = "B", .disabled = true },
    };
    try std.testing.expectEqual(@as(?usize, null), adjacentEnabled(&empty, 0, 1));
    try std.testing.expectEqual(@as(?usize, null), adjacentEnabled(&disabled, 0, 1));
}
