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
        .performance_updated => |snapshot| model.performance = snapshot,
        .platform_native_crash_recovered => |report| model.last_native_crash = report,
        .platform_crash_report_export_requested => {
            model.crash_report_export_attempted = false;
            model.crash_report_export_chooser_opened = false;
        },
        .platform_crash_report_export_started => |request_id| {
            model.last_crash_report_export_request_id = request_id;
            model.crash_report_export_pending = true;
            model.crash_report_export_attempted = false;
            model.crash_report_export_chooser_opened = false;
        },
        .platform_crash_report_export_result => |result| {
            if (result.request_id != model.last_crash_report_export_request_id) return;
            model.crash_report_export_pending = false;
            model.crash_report_export_attempted = true;
            model.crash_report_export_chooser_opened = result.chooser_opened;
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
        .semantic_scroll_requested => |request| {
            model.semantic_scroll_element_id = request.element_id;
            model.semantic_scroll_direction = if (request.direction < 0) -1 else 1;
        },
        .input_consumed => {
            model.pointer_pressed = false;
            model.pointer_released = false;
            model.scroll_delta_x = 0;
            model.scroll_delta_y = 0;
            model.semantic_scroll_element_id = null;
            model.semantic_scroll_direction = 0;
            model.back_requested = false;
            model.focus_next_requested = false;
            model.focus_previous_requested = false;
            model.focused_control_activate_requested = false;
            model.focused_control_up_requested = false;
            model.focused_control_down_requested = false;
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
        .focused_control_up_requested => model.focused_control_up_requested = true,
        .focused_control_down_requested => model.focused_control_down_requested = true,
        .focused_control_left_requested => model.focused_control_left_requested = true,
        .focused_control_right_requested => model.focused_control_right_requested = true,
        .text_field_focus_changed => |focused| {
            model.text_field_focused = focused;
            if (focused) {
                model.text_cursor = model.text_length;
                model.text_selection_anchor = model.text_cursor;
            } else {
                model.text_composition_length = 0;
            }
        },
        .text_inserted => |text| {
            model.text_composition_length = 0;
            insertSingleLine(model, text);
        },
        .text_backspace => backspace(model),
        .text_delete_selection => deleteSelection(model),
        .text_cursor_moved => |movement| moveCursor(model, movement.direction, movement.selecting),
        .text_cursor_set => |request| setCursor(model, request.position, request.selecting),
        .text_cursor_home => |selecting| setCursor(model, 0, selecting),
        .text_cursor_end => |selecting| setCursor(model, model.text_length, selecting),
        .text_select_all => {
            model.text_selection_anchor = 0;
            model.text_cursor = model.text_length;
        },
        .text_composition_changed => |text| setComposition(model, text),
        .text_composition_committed => |text| {
            model.text_composition_length = 0;
            insertSingleLine(model, text);
        },
        .text_composition_cancelled => model.text_composition_length = 0,
        .text_submitted => model.text_submission_count += 1,
        .platform_permission_requested => |permission| {
            model.permission_request_pending = true;
            model.last_permission = permission;
        },
        .platform_permission_result => |result| {
            model.permission_request_pending = false;
            model.last_permission_request_id = result.request_id;
            model.last_permission = result.permission;
            model.last_permission_granted = result.granted;
        },
        .platform_file_picker_requested => model.file_picker_pending = true,
        .platform_file_selected => |selection| {
            model.file_picker_pending = false;
            model.last_file_request_id = selection.request_id;
            setSelectedFileUri(model, selection.uri);
            model.file_read_pending = true;
            model.last_file_read_request_id = selection.request_id;
            model.file_preview_length = 0;
            model.file_preview_truncated = false;
            model.file_read_error = null;
            clearFileMetadata(model);
            resetFileStream(model);
        },
        .platform_file_selection_cancelled => |request_id| {
            model.file_picker_pending = false;
            model.last_file_request_id = request_id;
            model.file_selection_cancel_count += 1;
        },
        .platform_file_read_completed => |result| {
            if (result.request_id != model.last_file_read_request_id) return;
            model.file_read_pending = false;
            model.file_preview_length = @min(result.data.len, model.file_preview_buffer.len);
            @memcpy(model.file_preview_buffer[0..model.file_preview_length], result.data[0..model.file_preview_length]);
            model.file_preview_truncated = result.truncated or result.data.len > model.file_preview_buffer.len;
            model.file_read_error = null;
            model.file_display_name_length = copyUtf8Prefix(&model.file_display_name_buffer, result.display_name);
            model.file_mime_type_length = copyUtf8Prefix(&model.file_mime_type_buffer, result.mime_type);
            model.file_size = result.size orelse 0;
            model.file_size_known = result.size != null;
        },
        .platform_file_read_failed => |failure| {
            if (failure.request_id != model.last_file_read_request_id) return;
            model.file_read_pending = false;
            model.file_preview_length = 0;
            model.file_preview_truncated = false;
            model.file_read_error = failure.error_kind;
        },
        .platform_file_stream_requested => {
            resetFileStream(model);
            model.file_stream_pending = true;
        },
        .platform_file_stream_started => |request_id| {
            model.last_file_stream_request_id = request_id;
            model.file_stream_pending = true;
        },
        .platform_file_stream_cancel_requested => {
            if (model.file_stream_pending) model.file_stream_cancel_pending = true;
        },
        .platform_file_stream_chunk => |chunk| {
            if (chunk.request_id != model.last_file_stream_request_id or !model.file_stream_pending) return;
            if (chunk.offset != model.file_stream_bytes_consumed) {
                model.file_stream_pending = false;
                model.file_stream_cancel_pending = false;
                model.file_stream_error = .io;
                return;
            }
            for (chunk.data) |byte| {
                model.file_stream_hash ^= byte;
                model.file_stream_hash *%= 1099511628211;
            }
            model.file_stream_bytes_consumed += chunk.data.len;
            model.file_stream_chunk_count += 1;
        },
        .platform_file_stream_completed => |result| {
            if (result.request_id != model.last_file_stream_request_id) return;
            model.file_stream_pending = false;
            model.file_stream_cancel_pending = false;
            if (result.total_bytes == model.file_stream_bytes_consumed) {
                model.file_stream_completed = true;
                model.file_stream_cancelled = false;
                model.file_stream_error = null;
            } else {
                model.file_stream_completed = false;
                model.file_stream_error = .io;
            }
        },
        .platform_file_stream_failed => |failure| {
            if (failure.request_id != model.last_file_stream_request_id) return;
            model.file_stream_pending = false;
            model.file_stream_cancel_pending = false;
            model.file_stream_completed = false;
            model.file_stream_error = failure.error_kind;
        },
        .platform_file_stream_cancelled => |result| {
            if (result.request_id != model.last_file_stream_request_id) return;
            model.file_stream_pending = false;
            model.file_stream_cancel_pending = false;
            model.file_stream_completed = false;
            model.file_stream_cancelled = result.total_bytes == model.file_stream_bytes_consumed;
            model.file_stream_error = if (model.file_stream_cancelled) null else .io;
        },
        .demo_navigation_selected => |index| model.demo_navigation_index = index,
        .demo_tree_toggled => |index| {
            if (index < 64) model.demo_tree_expanded_mask ^= @as(u64, 1) << @intCast(index);
        },
        .demo_tree_selected => |index| model.demo_tree_selected_index = index,
        .demo_density_selected => |index| model.demo_density_index = @min(index, 2),
        .demo_sort_selected => |index| model.demo_sort_index = @min(index, 2),
        .demo_sort_expanded => |expanded| model.demo_sort_expanded = expanded,
        .demo_tab_selected => |index| model.demo_tab_index = @min(index, 2),
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

test "semantic scroll request is retained for one frame" {
    const std = @import("std");
    var model: Model = .{};

    update(&model, .{ .semantic_scroll_requested = .{
        .element_id = 42,
        .direction = -7,
    } });
    try std.testing.expectEqual(@as(?u32, 42), model.semantic_scroll_element_id);
    try std.testing.expectEqual(@as(i8, -1), model.semantic_scroll_direction);

    update(&model, .input_consumed);
    try std.testing.expectEqual(@as(?u32, null), model.semantic_scroll_element_id);
    try std.testing.expectEqual(@as(i8, 0), model.semantic_scroll_direction);
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

test "tree expansion and selection remain controlled by the model" {
    const std = @import("std");
    var model: Model = .{};
    update(&model, .{ .demo_tree_toggled = 0 });
    try std.testing.expectEqual(@as(u64, 0b10), model.demo_tree_expanded_mask);
    update(&model, .{ .demo_tree_selected = 4 });
    try std.testing.expectEqual(@as(u8, 4), model.demo_tree_selected_index);
}

test "radio selection remains controlled and bounded" {
    const std = @import("std");
    var model: Model = .{};
    update(&model, .{ .demo_density_selected = 2 });
    try std.testing.expectEqual(@as(u8, 2), model.demo_density_index);
    update(&model, .{ .demo_density_selected = 99 });
    try std.testing.expectEqual(@as(u8, 2), model.demo_density_index);
}

test "select selection and expansion remain controlled" {
    const std = @import("std");
    var model: Model = .{};
    update(&model, .{ .demo_sort_expanded = true });
    try std.testing.expect(model.demo_sort_expanded);
    update(&model, .{ .demo_sort_selected = 99 });
    try std.testing.expectEqual(@as(u8, 2), model.demo_sort_index);
    update(&model, .{ .demo_sort_expanded = false });
    try std.testing.expect(!model.demo_sort_expanded);
}

test "tab selection remains controlled and bounded" {
    const std = @import("std");
    var model: Model = .{};
    update(&model, .{ .demo_tab_selected = 2 });
    try std.testing.expectEqual(@as(u8, 2), model.demo_tab_index);
    update(&model, .{ .demo_tab_selected = 99 });
    try std.testing.expectEqual(@as(u8, 2), model.demo_tab_index);
}

test "UTF-8 cursor selection replaces complete codepoints" {
    const std = @import("std");
    var model: Model = .{};
    update(&model, .{ .text_inserted = "A中B" });
    update(&model, .{ .text_cursor_home = false });
    update(&model, .{ .text_cursor_moved = .{ .direction = 1, .selecting = false } });
    update(&model, .{ .text_cursor_moved = .{ .direction = 1, .selecting = true } });

    try std.testing.expectEqualStrings("中", model.selectedText());
    update(&model, .{ .text_inserted = "文" });
    try std.testing.expectEqualStrings("A文B", model.text());
    try std.testing.expect(!model.hasTextSelection());
}

test "select all and delete selection clear the field" {
    const std = @import("std");
    var model: Model = .{};
    update(&model, .{ .text_inserted = "copy me" });
    update(&model, .text_select_all);
    try std.testing.expectEqualStrings("copy me", model.selectedText());
    update(&model, .text_delete_selection);
    try std.testing.expectEqual(@as(usize, 0), model.text_length);
    try std.testing.expectEqual(@as(usize, 0), model.text_cursor);
}

test "IME composition remains provisional until committed" {
    const std = @import("std");
    var model: Model = .{};
    update(&model, .{ .text_inserted = "A" });
    update(&model, .{ .text_composition_changed = "zhong" });
    try std.testing.expectEqualStrings("A", model.text());
    try std.testing.expectEqualStrings("zhong", model.textComposition());

    update(&model, .{ .text_composition_committed = "中" });
    try std.testing.expectEqualStrings("A中", model.text());
    try std.testing.expectEqual(@as(usize, 0), model.text_composition_length);
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

test "platform results update permission and file picker state" {
    const std = @import("std");
    var model: Model = .{};

    update(&model, .{ .platform_permission_requested = .camera });
    try std.testing.expect(model.permission_request_pending);
    update(&model, .{ .platform_permission_result = .{
        .request_id = 7,
        .permission = .camera,
        .granted = true,
    } });
    try std.testing.expect(!model.permission_request_pending);
    try std.testing.expect(model.last_permission_granted);

    update(&model, .platform_file_picker_requested);
    try std.testing.expect(model.file_picker_pending);
    update(&model, .{ .platform_file_selected = .{
        .request_id = 8,
        .uri = "content://documents/example/中文.txt",
    } });
    try std.testing.expect(!model.file_picker_pending);
    try std.testing.expectEqualStrings("content://documents/example/中文.txt", model.selectedFileUri());
    try std.testing.expect(model.file_read_pending);

    update(&model, .{ .platform_file_read_completed = .{
        .request_id = 8,
        .data = "文件内容",
        .truncated = true,
        .display_name = "中文.txt",
        .mime_type = "text/plain",
        .size = 8192,
    } });
    try std.testing.expect(!model.file_read_pending);
    try std.testing.expectEqualStrings("文件内容", model.filePreview());
    try std.testing.expect(model.file_preview_truncated);
    try std.testing.expectEqualStrings("中文.txt", model.fileDisplayName());
    try std.testing.expectEqualStrings("text/plain", model.fileMimeType());
    try std.testing.expect(model.file_size_known);
    try std.testing.expectEqual(@as(u64, 8192), model.file_size);

    update(&model, .{ .platform_file_read_failed = .{
        .request_id = 7,
        .error_kind = .permission_denied,
    } });
    try std.testing.expect(model.file_read_error == null);

    update(&model, .platform_file_picker_requested);
    update(&model, .{ .platform_file_selection_cancelled = 9 });
    try std.testing.expectEqual(@as(u32, 1), model.file_selection_cancel_count);
}

test "matching file read failures clear pending preview state" {
    const std = @import("std");
    var model: Model = .{};
    update(&model, .{ .platform_file_selected = .{
        .request_id = 11,
        .uri = "content://documents/missing",
    } });
    update(&model, .{ .platform_file_read_failed = .{
        .request_id = 11,
        .error_kind = .not_found,
    } });
    try std.testing.expect(!model.file_read_pending);
    try std.testing.expect(model.file_read_error == .not_found);
    try std.testing.expectEqual(@as(usize, 0), model.filePreview().len);
}

test "file stream consumes ordered chunks and verifies terminal size" {
    const std = @import("std");
    var model: Model = .{};
    update(&model, .platform_file_stream_requested);
    update(&model, .{ .platform_file_stream_started = 21 });
    update(&model, .{ .platform_file_stream_chunk = .{
        .request_id = 21,
        .offset = 0,
        .data = "abc",
    } });
    update(&model, .{ .platform_file_stream_chunk = .{
        .request_id = 21,
        .offset = 3,
        .data = "def",
    } });

    var expected_hash: u64 = 14695981039346656037;
    for ("abcdef") |byte| {
        expected_hash ^= byte;
        expected_hash *%= 1099511628211;
    }
    try std.testing.expectEqual(@as(u64, 6), model.file_stream_bytes_consumed);
    try std.testing.expectEqual(@as(u64, 2), model.file_stream_chunk_count);
    try std.testing.expectEqual(expected_hash, model.file_stream_hash);

    update(&model, .{ .platform_file_stream_completed = .{
        .request_id = 21,
        .total_bytes = 6,
    } });
    try std.testing.expect(!model.file_stream_pending);
    try std.testing.expect(model.file_stream_completed);
    try std.testing.expect(model.file_stream_error == null);
}

test "file stream rejects discontinuous offsets" {
    const std = @import("std");
    var model: Model = .{};
    update(&model, .platform_file_stream_requested);
    update(&model, .{ .platform_file_stream_started = 22 });
    update(&model, .{ .platform_file_stream_chunk = .{
        .request_id = 22,
        .offset = 4,
        .data = "lost",
    } });
    try std.testing.expect(!model.file_stream_pending);
    try std.testing.expect(model.file_stream_error == .io);
    try std.testing.expectEqual(@as(u64, 0), model.file_stream_bytes_consumed);
}

fn insertSingleLine(model: *Model, text: []const u8) void {
    deleteSelection(model);
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
        var tail = model.text_length;
        while (tail > model.text_cursor) : (tail -= 1) {
            model.text_buffer[tail + sequence_length - 1] = model.text_buffer[tail - 1];
        }
        @memcpy(model.text_buffer[model.text_cursor .. model.text_cursor + sequence_length], text[index .. index + sequence_length]);
        model.text_length += sequence_length;
        model.text_cursor += sequence_length;
        model.text_selection_anchor = model.text_cursor;
        index += sequence_length;
    }
}

fn backspace(model: *Model) void {
    if (model.hasTextSelection()) {
        deleteSelection(model);
        return;
    }
    if (model.text_cursor == 0) return;
    const previous = previousCodepoint(model.text(), model.text_cursor);
    deleteRange(model, previous, model.text_cursor);
}

fn deleteSelection(model: *Model) void {
    if (!model.hasTextSelection()) return;
    deleteRange(model, model.selectionStart(), model.selectionEnd());
}

fn deleteRange(model: *Model, start: usize, end: usize) void {
    const removed = end - start;
    var index = end;
    while (index < model.text_length) : (index += 1) {
        model.text_buffer[index - removed] = model.text_buffer[index];
    }
    model.text_length -= removed;
    model.text_cursor = start;
    model.text_selection_anchor = start;
}

fn moveCursor(model: *Model, direction: i8, selecting: bool) void {
    if (!selecting and model.hasTextSelection()) {
        const target = if (direction < 0) model.selectionStart() else model.selectionEnd();
        setCursor(model, target, false);
        return;
    }
    const target = if (direction < 0)
        previousCodepoint(model.text(), model.text_cursor)
    else
        nextCodepoint(model.text(), model.text_cursor);
    setCursor(model, target, selecting);
}

fn setCursor(model: *Model, target: usize, selecting: bool) void {
    model.text_cursor = @min(target, model.text_length);
    if (!selecting) model.text_selection_anchor = model.text_cursor;
}

fn previousCodepoint(text: []const u8, cursor: usize) usize {
    if (cursor == 0) return 0;
    var index = cursor - 1;
    while (index > 0 and text[index] & 0xC0 == 0x80) index -= 1;
    return index;
}

fn nextCodepoint(text: []const u8, cursor: usize) usize {
    if (cursor >= text.len) return text.len;
    var index = cursor + 1;
    while (index < text.len and text[index] & 0xC0 == 0x80) index += 1;
    return index;
}

fn setComposition(model: *Model, text: []const u8) void {
    model.text_composition_length = 0;
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
        if (index + sequence_length > text.len or
            model.text_composition_length + sequence_length > model.text_composition_buffer.len) break;
        @memcpy(
            model.text_composition_buffer[model.text_composition_length .. model.text_composition_length + sequence_length],
            text[index .. index + sequence_length],
        );
        model.text_composition_length += sequence_length;
        index += sequence_length;
    }
}

fn setSelectedFileUri(model: *Model, uri: []const u8) void {
    model.selected_file_uri_length = copyUtf8Prefix(&model.selected_file_uri_buffer, uri);
}

fn clearFileMetadata(model: *Model) void {
    model.file_display_name_length = 0;
    model.file_mime_type_length = 0;
    model.file_size = 0;
    model.file_size_known = false;
}

fn resetFileStream(model: *Model) void {
    model.file_stream_pending = false;
    model.file_stream_cancel_pending = false;
    model.file_stream_completed = false;
    model.file_stream_cancelled = false;
    model.last_file_stream_request_id = 0;
    model.file_stream_bytes_consumed = 0;
    model.file_stream_chunk_count = 0;
    model.file_stream_hash = 14695981039346656037;
    model.file_stream_error = null;
}

fn copyUtf8Prefix(destination: []u8, source: []const u8) usize {
    var length = @min(source.len, destination.len);
    while (length > 0 and length < source.len and source[length] & 0xC0 == 0x80) length -= 1;
    @memcpy(destination[0..length], source[0..length]);
    return length;
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

test "performance snapshot is retained in the model" {
    const std = @import("std");
    var model: Model = .{};

    update(&model, .{ .performance_updated = .{
        .sample_count = 120,
        .fps = 59.8,
        .average_ui_cpu_ms = 0.75,
        .peak_command_count = 180,
    } });

    try std.testing.expectEqual(@as(u16, 120), model.performance.sample_count);
    try std.testing.expectEqual(@as(f32, 59.8), model.performance.fps);
    try std.testing.expectEqual(@as(f32, 0.75), model.performance.average_ui_cpu_ms);
    try std.testing.expectEqual(@as(u32, 180), model.performance.peak_command_count);
}
