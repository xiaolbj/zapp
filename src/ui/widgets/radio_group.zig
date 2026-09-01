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
    item_width: f32 = 260,
    direction: clay.LayoutDirection = .top_to_bottom,
    disabled: bool = false,
    focused_id: ?u32 = null,
    semantic_label: []const u8 = "Radio group",
    semantic_registry: ?*semantics.Registry = null,
};

pub const Result = struct {
    selected_index: ?usize = null,
    focus_index: ?usize = null,
};

/// Draws a controlled mutually-exclusive choice group. Pointer activation and
/// directional keyboard input only report the requested index; AppModel owns
/// the selected value.
pub fn draw(state: *interaction.State, input: interaction.Input, config: Config) Result {
    var output: Result = .{};
    const group_id = clay.ElementId.IDI(config.id, std.math.maxInt(u32));
    if (config.semantic_registry) |registry| _ = registry.add(.{
        .element_id = group_id.id,
        .role = .radio_group,
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
        for (config.items, 0..) |item, index| {
            const id = itemId(config.id, index);
            const focused = config.focused_id == id.id;
            const selected = config.selected_index == index;
            const pointer = interaction.update(state, id.id, clay.pointerOver(id), input, config.disabled);
            if (config.semantic_registry) |registry| _ = registry.add(.{
                .element_id = id.id,
                .role = .radio_button,
                .label = item.text,
                .checked = selected,
                .selected = selected,
                .disabled = config.disabled,
                .focused = focused,
            });

            const background: clay.Color = if (config.disabled)
                theme.controls.transparent
            else if (pointer.active)
                theme.controls.surface_focused
            else if (pointer.hovered or focused)
                theme.controls.surface_hover
            else
                theme.controls.transparent;
            const ring_color: clay.Color = if (config.disabled)
                theme.controls.surface_disabled_soft
            else if (selected)
                theme.controls.accent
            else
                theme.controls.control_inactive;

            clay.UI()(.{
                .id = id,
                .layout = .{
                    .sizing = .{ .w = .fixed(config.item_width), .h = .fixed(40) },
                    .padding = .axes(6, 4),
                    .child_gap = theme.controls.gap_medium,
                    .child_alignment = .{ .y = .center },
                },
                .background_color = background,
                .corner_radius = .all(theme.controls.radius_small),
                .border = .{
                    .color = theme.controls.focus,
                    .width = if (focused) .outside(theme.controls.focus_width) else .{},
                },
            })({
                clay.UI()(.{
                    .layout = .{
                        .sizing = .{ .w = .fixed(22), .h = .fixed(22) },
                        .child_alignment = .center,
                    },
                    .background_color = ring_color,
                    .corner_radius = .all(11),
                })({
                    clay.UI()(.{
                        .layout = .{ .sizing = .{ .w = .fixed(12), .h = .fixed(12) } },
                        .background_color = if (selected)
                            if (config.disabled) theme.controls.thumb_disabled else theme.controls.on_accent
                        else
                            theme.controls.surface,
                        .corner_radius = .all(6),
                    })({});
                });
                label.draw(item.text, .{
                    .color = if (config.disabled) theme.controls.text_disabled else theme.controls.text_secondary,
                });
            });

            if (pointer.clicked) {
                output.focus_index = index;
                output.selected_index = index;
            } else if (!config.disabled and focused) {
                if (input.activate_pressed) output.selected_index = index;
                const previous = input.left_pressed or input.up_pressed;
                const next = input.right_pressed or input.down_pressed;
                if (previous != next and config.items.len > 0) {
                    const target = adjacentIndex(index, config.items.len, if (previous) -1 else 1);
                    output.focus_index = target;
                    output.selected_index = target;
                }
            }
        }
    });
    return output;
}

pub fn itemId(group_id: []const u8, index: usize) clay.ElementId {
    return clay.ElementId.IDI(group_id, @intCast(index));
}

fn adjacentIndex(index: usize, count: usize, direction: i8) usize {
    if (count == 0) return 0;
    const current = @min(index, count - 1);
    if (direction < 0) return if (current == 0) count - 1 else current - 1;
    return (current + 1) % count;
}

test "radio group container id does not collide with first item" {
    const container = clay.ElementId.IDI("DensityRadio", std.math.maxInt(u32));
    try std.testing.expect(container.id != itemId("DensityRadio", 0).id);
}

test "radio keyboard navigation wraps in both directions" {
    try std.testing.expectEqual(@as(usize, 2), adjacentIndex(0, 3, -1));
    try std.testing.expectEqual(@as(usize, 0), adjacentIndex(2, 3, 1));
    try std.testing.expectEqual(@as(usize, 1), adjacentIndex(0, 3, 1));
    try std.testing.expectEqual(@as(usize, 0), adjacentIndex(9, 0, 1));
}
