const clay = @import("zclay");
const theme = @import("../theme.zig");

pub const Config = struct {
    value: f32,
    width: f32 = 260,
    height: f32 = 16,
    track_color: clay.Color = theme.controls.surface_muted,
    fill_color: clay.Color = theme.controls.accent_hover,
};

pub fn draw(config: Config) void {
    const value = clamp(config.value);
    clay.UI()(.{
        .layout = .{ .sizing = .{ .w = .fixed(config.width), .h = .fixed(config.height) } },
        .background_color = config.track_color,
        .corner_radius = .all(config.height * 0.5),
        .clip = .{ .horizontal = true },
    })({
        clay.UI()(.{
            .layout = .{ .sizing = .{
                .w = .fixed(config.width * value),
                .h = .fixed(config.height),
            } },
            .background_color = config.fill_color,
            .corner_radius = .all(config.height * 0.5),
        })({});
    });
}

pub fn clamp(value: f32) f32 {
    return @min(@max(value, 0), 1);
}

test "progress value is clamped to its valid range" {
    const std = @import("std");
    try std.testing.expectEqual(@as(f32, 0), clamp(-0.5));
    try std.testing.expectEqual(@as(f32, 0.4), clamp(0.4));
    try std.testing.expectEqual(@as(f32, 1), clamp(2));
}
