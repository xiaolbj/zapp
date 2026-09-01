const clay = @import("zclay");
const label = @import("label.zig");
const theme = @import("../theme.zig");

pub const State = struct {
    message_buffer: [256]u8 = @splat(0),
    message_length: usize = 0,
    remaining_seconds: f32 = 0,

    pub fn show(self: *State, text: []const u8, duration_seconds: f32) void {
        self.message_length = @min(text.len, self.message_buffer.len);
        @memcpy(self.message_buffer[0..self.message_length], text[0..self.message_length]);
        self.remaining_seconds = @max(duration_seconds, 0);
    }

    pub fn update(self: *State, delta_seconds: f32) void {
        self.remaining_seconds = @max(self.remaining_seconds - @max(delta_seconds, 0), 0);
    }

    pub fn visible(self: *const State) bool {
        return self.remaining_seconds > 0 and self.message_length > 0;
    }

    pub fn message(self: *const State) []const u8 {
        return self.message_buffer[0..self.message_length];
    }
};

pub fn draw(state: *const State, viewport_width: f32) void {
    if (!state.visible()) return;
    const width = @min(420, @max(viewport_width - 48, 220));
    clay.UI()(.{
        .id = .ID("GlobalToast"),
        .layout = .{
            .sizing = .{ .w = .fixed(width), .h = .fit },
            .padding = .axes(18, 14),
            .child_alignment = .center,
        },
        .background_color = theme.controls.success,
        .corner_radius = .all(theme.controls.radius_medium),
        .floating = .{
            .offset = .{ .x = 0, .y = -28 },
            .z_index = 200,
            .attach_points = .{ .element = .center_bottom, .parent = .center_bottom },
            .pointer_capture_mode = .passthrough,
            .attach_to = .to_root,
        },
    })({
        label.draw(state.message(), .{ .font_size = 16, .color = theme.controls.toast_text });
    });
}

test "toast expires after its duration" {
    const std = @import("std");
    var state: State = .{};
    state.show("saved", 2);
    try std.testing.expect(state.visible());
    state.update(2.1);
    try std.testing.expect(!state.visible());
}
