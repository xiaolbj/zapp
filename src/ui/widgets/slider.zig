const clay = @import("zclay");
const interaction = @import("interaction.zig");
const theme = @import("../theme.zig");

pub const Config = struct {
    id: []const u8,
    value: f32,
    width: f32 = 260,
    disabled: bool = false,
    focused: bool = false,
    track_color: clay.Color = theme.controls.surface_muted,
    fill_color: clay.Color = theme.controls.accent_hover,
};

const thumb_size: f32 = 20;

/// Draws a controlled slider and returns a new value while it is dragged.
pub fn draw(state: *interaction.State, input: interaction.Input, config: Config) ?f32 {
    const id = clay.ElementId.ID(config.id);
    const result = interaction.update(state, id.id, clay.pointerOver(id), input, config.disabled);
    const value = clamp(config.value);
    const span = @max(config.width - thumb_size, 1);
    const fill_width = span * value;
    const remaining_width = span - fill_width;

    clay.UI()(.{
        .id = id,
        .layout = .{
            .sizing = .{ .w = .fixed(config.width), .h = .fixed(32) },
            .child_alignment = .{ .y = .center },
        },
        .border = .{
            .color = theme.controls.focus,
            .width = if (config.focused) .outside(theme.controls.focus_width) else .{},
        },
        .corner_radius = .all(theme.controls.radius_small),
    })({
        clay.UI()(.{
            .layout = .{ .sizing = .{ .w = .fixed(fill_width), .h = .fixed(8) } },
            .background_color = if (config.disabled) theme.controls.track_disabled else config.fill_color,
            .corner_radius = .all(theme.controls.radius_track),
        })({});
        clay.UI()(.{
            .layout = .{ .sizing = .{ .w = .fixed(thumb_size), .h = .fixed(thumb_size) } },
            .background_color = if (config.disabled)
                theme.controls.text_disabled
            else if (result.active or config.focused)
                theme.controls.thumb_focused
            else
                theme.controls.on_accent,
            .corner_radius = .all(thumb_size * 0.5),
        })({});
        clay.UI()(.{
            .layout = .{ .sizing = .{ .w = .fixed(remaining_width), .h = .fixed(8) } },
            .background_color = config.track_color,
            .corner_radius = .all(theme.controls.radius_track),
        })({});
    });

    if (!config.disabled and (result.active or result.clicked)) {
        const data = clay.getElementData(id);
        if (data.found) return valueFromPointer(input.x, data.bounding_box.x, config.width);
    }
    if (!config.disabled and config.focused) {
        if (input.left_pressed or input.right_pressed) {
            return adjust(value, input.left_pressed, input.right_pressed);
        }
    }
    return null;
}

pub fn adjust(value: f32, left_pressed: bool, right_pressed: bool) f32 {
    if (left_pressed and !right_pressed) return clamp(value - 0.05);
    if (right_pressed and !left_pressed) return clamp(value + 0.05);
    return clamp(value);
}

pub fn valueFromPointer(pointer_x: f32, bounds_x: f32, width: f32) f32 {
    const span = @max(width - thumb_size, 1);
    return clamp((pointer_x - bounds_x - thumb_size * 0.5) / span);
}

fn clamp(value: f32) f32 {
    return @min(@max(value, 0), 1);
}

test "pointer position maps to a clamped slider value" {
    const std = @import("std");
    try std.testing.expectEqual(@as(f32, 0), valueFromPointer(50, 100, 220));
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), valueFromPointer(210, 100, 220), 0.0001);
    try std.testing.expectEqual(@as(f32, 1), valueFromPointer(400, 100, 220));
}

test "keyboard adjustment changes slider by one step" {
    const std = @import("std");
    try std.testing.expectApproxEqAbs(@as(f32, 0.45), adjust(0.5, true, false), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.55), adjust(0.5, false, true), 0.0001);
    try std.testing.expectEqual(@as(f32, 0), adjust(0.01, true, false));
}
