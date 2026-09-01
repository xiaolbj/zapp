pub const State = struct {
    active_id: ?u32 = null,
};

pub const Input = struct {
    down: bool,
    pressed: bool,
    released: bool,
};

pub const Result = struct {
    hovered: bool,
    active: bool,
    clicked: bool,
};

pub fn update(state: *State, id: u32, hovered: bool, input: Input, disabled: bool) Result {
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

test "click completes only when released over the active control" {
    const std = @import("std");
    var state: State = .{};

    const pressed = update(&state, 7, true, .{ .down = true, .pressed = true, .released = false }, false);
    try std.testing.expect(pressed.active);
    try std.testing.expect(!pressed.clicked);

    const released = update(&state, 7, true, .{ .down = false, .pressed = false, .released = true }, false);
    try std.testing.expect(released.clicked);
    try std.testing.expectEqual(@as(?u32, null), state.active_id);
}

test "release outside cancels the active control" {
    const std = @import("std");
    var state: State = .{};

    _ = update(&state, 7, true, .{ .down = true, .pressed = true, .released = false }, false);
    const released = update(&state, 7, false, .{ .down = false, .pressed = false, .released = true }, false);

    try std.testing.expect(!released.clicked);
    try std.testing.expectEqual(@as(?u32, null), state.active_id);
}

test "disabled control cannot retain pointer capture" {
    const std = @import("std");
    var state: State = .{ .active_id = 7 };

    const result = update(&state, 7, true, .{ .down = true, .pressed = false, .released = false }, true);

    try std.testing.expect(!result.hovered);
    try std.testing.expect(!result.active);
    try std.testing.expectEqual(@as(?u32, null), state.active_id);
}
