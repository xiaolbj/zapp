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
            model.focus_next_requested = false;
            model.focus_previous_requested = false;
            model.focused_control_activate_requested = false;
            model.focused_control_left_requested = false;
            model.focused_control_right_requested = false;
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
        .focus_next_requested => model.focus_next_requested = true,
        .focus_previous_requested => model.focus_previous_requested = true,
        .focused_control_activate_requested => model.focused_control_activate_requested = true,
        .focused_control_left_requested => model.focused_control_left_requested = true,
        .focused_control_right_requested => model.focused_control_right_requested = true,
        .text_field_focus_changed => |focused| model.text_field_focused = focused,
        .text_inserted => |text| appendSingleLine(model, text),
        .text_backspace => deleteLastCodepoint(model),
        .text_submitted => model.text_submission_count += 1,
        .demo_navigation_selected => |index| model.demo_navigation_index = index,
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

test "text input appends UTF-8 and deletes a complete codepoint" {
    const std = @import("std");
    var model: Model = .{};

    update(&model, .{ .text_inserted = "hello世界" });
    try std.testing.expectEqualStrings("hello世界", model.text());
    update(&model, .text_backspace);
    try std.testing.expectEqualStrings("hello世", model.text());
    update(&model, .{ .text_inserted = "\nignored" });
    try std.testing.expectEqualStrings("hello世", model.text());
}

test "text input never splits a UTF-8 sequence at capacity" {
    const std = @import("std");
    var model: Model = .{};
    const ascii = "a" ** 255;
    update(&model, .{ .text_inserted = ascii });
    update(&model, .{ .text_inserted = "中" });

    try std.testing.expectEqual(@as(usize, 255), model.text_length);
    try std.testing.expect(std.unicode.utf8ValidateSlice(model.text()));
}

test "text submission and navigation remain controlled by the model" {
    const std = @import("std");
    var model: Model = .{};

    update(&model, .{ .text_field_focus_changed = true });
    update(&model, .text_submitted);
    update(&model, .{ .demo_navigation_selected = 2 });

    try std.testing.expect(model.text_field_focused);
    try std.testing.expectEqual(@as(u32, 1), model.text_submission_count);
    try std.testing.expectEqual(@as(u8, 2), model.demo_navigation_index);
}

test "keyboard navigation requests are frame-latched" {
    const std = @import("std");
    var model: Model = .{};
    update(&model, .focus_previous_requested);
    update(&model, .focused_control_activate_requested);
    update(&model, .focused_control_right_requested);

    try std.testing.expect(model.focus_previous_requested);
    try std.testing.expect(model.focused_control_activate_requested);
    try std.testing.expect(model.focused_control_right_requested);
    update(&model, .input_consumed);
    try std.testing.expect(!model.focus_previous_requested);
    try std.testing.expect(!model.focused_control_activate_requested);
    try std.testing.expect(!model.focused_control_right_requested);
}

fn appendSingleLine(model: *Model, text: []const u8) void {
    var index: usize = 0;
    while (index < text.len) {
        const first = text[index];
        if (first == '\r' or first == '\n') break;
        const sequence_length: usize = if (first < 0x80)
            1
        else if (first & 0xE0 == 0xC0)
            2
        else if (first & 0xF0 == 0xE0)
            3
        else if (first & 0xF8 == 0xF0)
            4
        else
            1;
        if (index + sequence_length > text.len) break;
        if (model.text_length + sequence_length > model.text_buffer.len) break;
        @memcpy(
            model.text_buffer[model.text_length .. model.text_length + sequence_length],
            text[index .. index + sequence_length],
        );
        model.text_length += sequence_length;
        index += sequence_length;
    }
}

fn deleteLastCodepoint(model: *Model) void {
    if (model.text_length == 0) return;
    model.text_length -= 1;
    while (model.text_length > 0 and model.text_buffer[model.text_length] & 0xC0 == 0x80) {
        model.text_length -= 1;
    }
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
