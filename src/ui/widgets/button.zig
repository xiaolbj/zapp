const clay = @import("zclay");
const label = @import("label.zig");

pub const State = struct {
    active_id: ?u32 = null,
};

pub const Input = struct {
    down: bool,
    pressed: bool,
    released: bool,
};

pub const Config = struct {
    id: []const u8,
    text: []const u8,
    width: f32 = 200,
    disabled: bool = false,
    normal_color: clay.Color = .{ 42, 111, 204, 255 },
    hover_color: clay.Color = .{ 55, 132, 229, 255 },
    pressed_color: clay.Color = .{ 30, 85, 164, 255 },
    disabled_color: clay.Color = .{ 64, 75, 94, 255 },
};

pub const Interaction = struct {
    hovered: bool,
    active: bool,
    clicked: bool,
};

pub fn draw(state: *State, input: Input, config: Config) bool {
    const id = clay.ElementId.ID(config.id);
    const interaction = updateInteraction(state, id.id, clay.pointerOver(id), input, config.disabled);
    const color = if (config.disabled)
        config.disabled_color
    else if (interaction.active)
        config.pressed_color
    else if (interaction.hovered)
        config.hover_color
    else
        config.normal_color;

    clay.UI()(.{
        .id = id,
        .layout = .{
            .sizing = .{ .w = .fixed(config.width), .h = .fixed(48) },
            .padding = .axes(20, 12),
            .child_alignment = .center,
        },
        .background_color = color,
        .corner_radius = .all(10),
    })({
        label.draw(config.text, .{
            .font_size = 16,
            .color = if (config.disabled) .{ 154, 164, 181, 255 } else .{ 248, 251, 255, 255 },
        });
    });

    return interaction.clicked;
}

pub fn updateInteraction(state: *State, id: u32, hovered: bool, input: Input, disabled: bool) Interaction {
    if (disabled) {
        if (state.active_id == id) state.active_id = null;
        return .{ .hovered = false, .active = false, .clicked = false };
    }

    if (input.pressed and hovered) state.active_id = id;
    const active = state.active_id == id and input.down;
    var clicked = false;
    if (input.released and state.active_id == id) {
        clicked = hovered;
        state.active_id = null;
    }
    return .{ .hovered = hovered, .active = active, .clicked = clicked };
}

test "button clicks after press and release inside" {
    const std = @import("std");
    var state: State = .{};

    const pressed = updateInteraction(&state, 7, true, .{ .down = true, .pressed = true, .released = false }, false);
    try std.testing.expect(pressed.active);
    try std.testing.expect(!pressed.clicked);

    const released = updateInteraction(&state, 7, true, .{ .down = false, .pressed = false, .released = true }, false);
    try std.testing.expect(released.clicked);
    try std.testing.expectEqual(@as(?u32, null), state.active_id);
}

test "button cancels when released outside" {
    const std = @import("std");
    var state: State = .{};

    _ = updateInteraction(&state, 7, true, .{ .down = true, .pressed = true, .released = false }, false);
    const released = updateInteraction(&state, 7, false, .{ .down = false, .pressed = false, .released = true }, false);

    try std.testing.expect(!released.clicked);
    try std.testing.expectEqual(@as(?u32, null), state.active_id);
}
