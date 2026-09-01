const Action = @import("action.zig").Action;
const Model = @import("model.zig").Model;

pub fn update(model: *Model, action: Action) void {
    switch (action) {
        .tick => |seconds| {
            if (!model.suspended) {
                model.frame_count += 1;
                model.elapsed_seconds += seconds;
                model.frame_delta_seconds = @floatCast(seconds);
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
            if (pointer.down and !model.pointer_down) model.pointer_pressed = true;
            if (!pointer.down and model.pointer_down) model.pointer_released = true;
            model.pointer_down = pointer.down;
        },
        .scroll_changed => |delta| {
            model.scroll_delta_x += delta.x;
            model.scroll_delta_y += delta.y;
        },
        .input_consumed => {
            model.pointer_pressed = false;
            model.pointer_released = false;
            model.scroll_delta_x = 0;
            model.scroll_delta_y = 0;
            model.back_requested = false;
        },
        .primary_button_pressed => model.primary_button_presses += 1,
        .demo_checkbox_toggled => model.demo_checkbox_checked = !model.demo_checkbox_checked,
        .demo_switch_toggled => model.demo_switch_checked = !model.demo_switch_checked,
        .demo_progress_incremented => {
            model.demo_progress += 0.1;
            if (model.demo_progress > 1.001) model.demo_progress = 0;
        },
        .demo_volume_changed => |value| model.demo_volume = @min(@max(value, 0), 1),
        .demo_dialog_opened => model.demo_dialog_open = true,
        .demo_dialog_closed => model.demo_dialog_open = false,
        .demo_dialog_confirmed => {
            model.demo_dialog_confirmations += 1;
            model.demo_dialog_open = false;
        },
        .back_requested => model.back_requested = true,
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
    try std.testing.expect(model.pointer_pressed);

    update(&model, .{ .pointer_changed = .{
        .x = 120,
        .y = 80,
        .down = false,
    } });
    try std.testing.expect(model.pointer_released);

    update(&model, .input_consumed);
    try std.testing.expect(!model.pointer_pressed);
    try std.testing.expect(!model.pointer_released);
}

test "button action updates application state" {
    const std = @import("std");
    var model: Model = .{};

    update(&model, .primary_button_pressed);
    update(&model, .primary_button_pressed);

    try std.testing.expectEqual(@as(u32, 2), model.primary_button_presses);
}

test "selection controls toggle application state" {
    const std = @import("std");
    var model: Model = .{};

    update(&model, .demo_checkbox_toggled);
    update(&model, .demo_switch_toggled);

    try std.testing.expect(model.demo_checkbox_checked);
    try std.testing.expect(!model.demo_switch_checked);
}

test "scroll input accumulates until consumed" {
    const std = @import("std");
    var model: Model = .{};

    update(&model, .{ .scroll_changed = .{ .x = 1, .y = -2 } });
    update(&model, .{ .scroll_changed = .{ .x = 0, .y = -3 } });
    try std.testing.expectEqual(@as(f32, 1), model.scroll_delta_x);
    try std.testing.expectEqual(@as(f32, -5), model.scroll_delta_y);

    update(&model, .input_consumed);
    try std.testing.expectEqual(@as(f32, 0), model.scroll_delta_x);
    try std.testing.expectEqual(@as(f32, 0), model.scroll_delta_y);
}

test "progress action advances and wraps" {
    const std = @import("std");
    var model: Model = .{ .demo_progress = 0.95 };

    update(&model, .demo_progress_incremented);
    try std.testing.expectEqual(@as(f32, 0), model.demo_progress);
}

test "volume action clamps controlled slider state" {
    const std = @import("std");
    var model: Model = .{};

    update(&model, .{ .demo_volume_changed = 1.5 });
    try std.testing.expectEqual(@as(f32, 1), model.demo_volume);
    update(&model, .{ .demo_volume_changed = -0.2 });
    try std.testing.expectEqual(@as(f32, 0), model.demo_volume);
}

test "dialog actions update modal state and confirmation count" {
    const std = @import("std");
    var model: Model = .{};

    update(&model, .demo_dialog_opened);
    try std.testing.expect(model.demo_dialog_open);
    update(&model, .demo_dialog_confirmed);
    try std.testing.expect(!model.demo_dialog_open);
    try std.testing.expectEqual(@as(u32, 1), model.demo_dialog_confirmations);

    update(&model, .back_requested);
    try std.testing.expect(model.back_requested);
    update(&model, .input_consumed);
    try std.testing.expect(!model.back_requested);
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
