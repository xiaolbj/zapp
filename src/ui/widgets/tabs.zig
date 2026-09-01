const std = @import("std");
const clay = @import("zclay");
const interaction = @import("interaction.zig");
const label = @import("label.zig");
const semantics = @import("../semantics.zig");
const theme = @import("../theme.zig");

pub const Item = struct {
    text: []const u8,
};

pub const Config = struct {
    id: []const u8,
    items: []const Item,
    selected_index: usize,
    item_width: f32 = 140,
    direction: clay.LayoutDirection = .left_to_right,
    disabled: bool = false,
    focused_id: ?u32 = null,
    semantic_label: []const u8 = "Tabs",
    semantic_registry: ?*semantics.Registry = null,
};

pub const Result = struct {
    selected_index: ?usize = null,
    focus_index: ?usize = null,
};

/// Draws a controlled tab list with automatic activation. Pointer input and
/// the orientation-appropriate arrow keys report a new active index; content
/// rendering remains the caller's responsibility.
pub fn draw(state: *interaction.State, input: interaction.Input, config: Config) Result {
    var output: Result = .{};
    const list_id = clay.ElementId.IDI(config.id, std.math.maxInt(u32));
    const active_index = boundedIndex(config.selected_index, config.items.len);
    if (config.semantic_registry) |registry| _ = registry.add(.{
        .element_id = list_id.id,
        .role = .tab_list,
        .label = config.semantic_label,
        .disabled = config.disabled,
    });

    clay.UI()(.{
        .id = list_id,
        .layout = .{
            .sizing = .fit,
            .child_gap = theme.controls.gap_tiny,
            .direction = config.direction,
        },
    })({
        for (config.items, 0..) |item, index| {
            const id = itemId(config.id, index);
            const focused = config.focused_id == id.id;
            const selected = active_index == index;
            const pointer = interaction.update(state, id.id, clay.pointerOver(id), input, config.disabled);
            if (config.semantic_registry) |registry| _ = registry.add(.{
                .element_id = id.id,
                .role = .tab,
                .label = item.text,
                .disabled = config.disabled,
                .focused = focused,
                .selected = selected,
            });

            const background: clay.Color = if (config.disabled)
                theme.controls.input_disabled
            else if (pointer.active)
                theme.controls.surface_focused
            else if (selected)
                theme.controls.navigation_active
            else if (pointer.hovered or focused)
                theme.controls.surface_hover
            else
                theme.controls.surface;
            const horizontal = isHorizontal(config.direction);
            const selected_border: clay.BorderWidth = if (horizontal)
                .{ .bottom = 3 }
            else
                .{ .left = 3 };
            clay.UI()(.{
                .id = id,
                .layout = .{
                    .sizing = .{ .w = .fixed(config.item_width), .h = .fixed(44) },
                    .padding = .axes(14, 9),
                    .child_alignment = .center,
                },
                .background_color = background,
                .corner_radius = .all(theme.controls.radius_small),
                .border = .{
                    .color = if (focused) theme.controls.focus else theme.controls.accent_hover,
                    .width = if (focused)
                        .outside(theme.controls.focus_width)
                    else if (selected)
                        selected_border
                    else
                        .{},
                },
            })({
                label.draw(item.text, .{
                    .font_size = 15,
                    .color = if (config.disabled)
                        theme.controls.text_disabled
                    else if (selected)
                        theme.controls.on_accent
                    else
                        theme.controls.text_secondary,
                });
            });

            if (pointer.clicked) {
                output.focus_index = index;
                output.selected_index = index;
            } else if (!config.disabled and focused) {
                if (input.activate_pressed) output.selected_index = index;
                const delta = navigationDelta(config.direction, input);
                if (delta != 0 and config.items.len > 0) {
                    const target = adjacentIndex(index, config.items.len, delta);
                    output.focus_index = target;
                    output.selected_index = target;
                }
            }
        }
    });
    return output;
}

pub fn itemId(tabs_id: []const u8, index: usize) clay.ElementId {
    return clay.ElementId.IDI(tabs_id, @intCast(index));
}

pub fn boundedIndex(index: usize, count: usize) ?usize {
    if (count == 0) return null;
    return @min(index, count - 1);
}

fn isHorizontal(direction: clay.LayoutDirection) bool {
    return direction == .left_to_right;
}

fn navigationDelta(direction: clay.LayoutDirection, input: interaction.Input) i8 {
    const previous = if (isHorizontal(direction)) input.left_pressed else input.up_pressed;
    const next = if (isHorizontal(direction)) input.right_pressed else input.down_pressed;
    if (previous == next) return 0;
    return if (previous) -1 else 1;
}

fn adjacentIndex(index: usize, count: usize, direction: i8) usize {
    if (count == 0) return 0;
    const current = @min(index, count - 1);
    if (direction < 0) return if (current == 0) count - 1 else current - 1;
    return (current + 1) % count;
}

test "tab list container id does not collide with tabs" {
    const container = clay.ElementId.IDI("DataTabs", std.math.maxInt(u32));
    try std.testing.expect(container.id != itemId("DataTabs", 0).id);
    try std.testing.expect(itemId("DataTabs", 0).id != itemId("DataTabs", 1).id);
}

test "tab selection bounds and wraps" {
    try std.testing.expectEqual(@as(?usize, null), boundedIndex(4, 0));
    try std.testing.expectEqual(@as(?usize, 2), boundedIndex(8, 3));
    try std.testing.expectEqual(@as(usize, 2), adjacentIndex(0, 3, -1));
    try std.testing.expectEqual(@as(usize, 0), adjacentIndex(2, 3, 1));
}

test "tab navigation follows orientation" {
    const horizontal = navigationDelta(.left_to_right, .{
        .down = false,
        .pressed = false,
        .released = false,
        .right_pressed = true,
    });
    const vertical = navigationDelta(.top_to_bottom, .{
        .down = false,
        .pressed = false,
        .released = false,
        .up_pressed = true,
    });
    try std.testing.expectEqual(@as(i8, 1), horizontal);
    try std.testing.expectEqual(@as(i8, -1), vertical);
}
