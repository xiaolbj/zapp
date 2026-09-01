const Action = @import("action.zig").Action;
const Model = @import("model.zig").Model;

pub fn update(model: *Model, action: Action) void {
    switch (action) {
        .tick => |seconds| {
            if (!model.suspended) {
                model.frame_count += 1;
                model.elapsed_seconds += seconds;
            }
        },
        .resized => |viewport| {
            model.viewport_width = viewport.width;
            model.viewport_height = viewport.height;
            model.dpi_scale = viewport.dpi_scale;
        },
        .pointer_changed => |pointer| {
            model.pointer_x = pointer.x;
            model.pointer_y = pointer.y;
            model.pointer_down = pointer.down;
        },
        .suspended => model.suspended = true,
        .resumed => model.suspended = false,
    }
}

test "pointer state is retained for Clay interaction" {
    const std = @import("std");
    var model: Model = .{};

    update(&model, .{ .pointer_changed = .{
        .x = 120,
        .y = 80,
        .down = true,
    } });

    try std.testing.expectEqual(@as(f32, 120), model.pointer_x);
    try std.testing.expectEqual(@as(f32, 80), model.pointer_y);
    try std.testing.expect(model.pointer_down);
}

test "tick advances only while active" {
    const std = @import("std");
    var model: Model = .{};

    update(&model, .{ .tick = 0.25 });
    try std.testing.expectEqual(@as(u64, 1), model.frame_count);
    try std.testing.expectEqual(@as(f64, 0.25), model.elapsed_seconds);

    update(&model, .suspended);
    update(&model, .{ .tick = 1.0 });
    try std.testing.expectEqual(@as(u64, 1), model.frame_count);
    try std.testing.expectEqual(@as(f64, 0.25), model.elapsed_seconds);
}

test "resize updates framebuffer dimensions and dpi" {
    const std = @import("std");
    var model: Model = .{};

    update(&model, .{ .resized = .{
        .width = 2560,
        .height = 1440,
        .dpi_scale = 2,
    } });

    try std.testing.expectEqual(@as(i32, 2560), model.viewport_width);
    try std.testing.expectEqual(@as(i32, 1440), model.viewport_height);
    try std.testing.expectEqual(@as(f32, 2), model.dpi_scale);
}
