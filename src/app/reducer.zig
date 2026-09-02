const Action = @import("action.zig").Action;
const Model = @import("model.zig").Model;
const runtime_image = @import("../assets/runtime_image.zig");
const text_edit = @import("text_edit.zig");

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
            model.focused_control_home_requested = false;
            model.focused_control_end_requested = false;
        },
        .primary_button_pressed => model.primary_button_presses += 1,
        .demo_checkbox_toggled => model.demo_checkbox_checked = !model.demo_checkbox_checked,
        .demo_switch_toggled => model.demo_switch_checked = !model.demo_switch_checked,
        .demo_progress_incremented => {
            model.demo_progress += 0.1;
            if (model.demo_progress > 1.001) model.demo_progress = 0;
        },
        .demo_volume_changed => |value| model.demo_volume = @min(@max(value, 0), 1),
        .demo_retry_count_changed => |value| model.demo_retry_count = @min(@max(value, 0), 10),
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
        .focused_control_home_requested => model.focused_control_home_requested = true,
        .focused_control_end_requested => model.focused_control_end_requested = true,
        .text_input_focus_changed => |target| {
            if (model.activeTextInput()) |current| current.blur();
            model.active_text_input = target;
            if (model.activeTextInput()) |current| current.focus();
        },
        .text_cleared => |target| model.textInput(target).clear(),
        .text_inserted => |text| {
            const input = editingInput(model);
            input.cancelComposition();
            input.insertSingleLine(text);
        },
        .text_backspace => editingInput(model).backspace(),
        .text_delete_selection => editingInput(model).deleteSelection(),
        .text_cursor_moved => |movement| editingInput(model).moveCursor(movement.direction, movement.selecting),
        .text_cursor_set => |request| editingInput(model).setCursor(request.position, request.selecting),
        .text_cursor_home => |selecting| editingInput(model).setCursor(0, selecting),
        .text_cursor_end => |selecting| {
            const input = editingInput(model);
            input.setCursor(input.length, selecting);
        },
        .text_select_all => editingInput(model).selectAll(),
        .text_composition_changed => |text| editingInput(model).setComposition(text),
        .text_composition_committed => |text| editingInput(model).commitComposition(text),
        .text_composition_cancelled => editingInput(model).cancelComposition(),
        .text_submitted => editingInput(model).submit(),
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
        .platform_runtime_image_load_requested => {
            model.runtime_image_source_remote = false;
            model.runtime_image_error = null;
            model.runtime_image_bytes_received = 0;
        },
        .platform_remote_image_load_requested => {
            model.runtime_image_source_remote = true;
            model.runtime_image_error = null;
            model.runtime_image_bytes_received = 0;
        },
        .platform_runtime_image_load_started => |request_id| {
            model.last_runtime_image_request_id = request_id;
            model.runtime_image_load_pending = true;
            model.runtime_image_cancel_pending = false;
            model.runtime_image_bytes_received = 0;
            model.runtime_image_error = null;
        },
        .platform_runtime_image_load_cancel_requested => {
            if (model.runtime_image_load_pending) model.runtime_image_cancel_pending = true;
        },
        .platform_remote_image_load_cancel_requested => {
            if (model.runtime_image_load_pending and model.runtime_image_source_remote)
                model.runtime_image_cancel_pending = true;
        },
        .platform_runtime_image_load_progress => |progress| {
            if (progress.request_id != model.last_runtime_image_request_id or
                !model.runtime_image_load_pending) return;
            model.runtime_image_bytes_received = progress.bytes_received;
        },
        .platform_runtime_image_load_succeeded => |result| {
            if (result.request_id != model.last_runtime_image_request_id) return;
            model.runtime_image_load_pending = false;
            model.runtime_image_cancel_pending = false;
            model.runtime_image_loaded = true;
            model.runtime_image_bytes_received = result.encoded_bytes;
            model.runtime_image_resource = result.resource;
            model.runtime_image_width = result.width;
            model.runtime_image_height = result.height;
            model.runtime_image_cache_hit = result.cache_hit;
            model.runtime_image_cached_count = result.cached_count;
            model.runtime_image_error = null;
            model.last_runtime_image_cache_clear_reason = null;
            model.last_runtime_image_budget_released_count = 0;
        },
        .platform_runtime_image_load_failed => |failure| {
            if (failure.request_id != model.last_runtime_image_request_id) return;
            model.runtime_image_load_pending = false;
            model.runtime_image_cancel_pending = false;
            model.runtime_image_error = failure.error_kind;
        },
        .platform_runtime_image_load_cancelled => |result| {
            if (result.request_id != model.last_runtime_image_request_id) return;
            model.runtime_image_load_pending = false;
            model.runtime_image_cancel_pending = false;
            model.runtime_image_bytes_received = result.total_bytes;
            model.runtime_image_error = .interrupted;
        },
        .platform_memory_pressure_received => |level| {
            model.memory_pressure_event_count +%= 1;
            model.last_memory_pressure_level = level;
        },
        .runtime_image_cache_clear_requested => |reason| {
            model.runtime_image_cache_clear_requested = true;
            model.runtime_image_cache_clear_reason = reason;
        },
        .runtime_image_cache_cleared => |result| {
            model.runtime_image_cache_clear_requested = false;
            model.runtime_image_loaded = false;
            model.runtime_image_cache_hit = false;
            model.runtime_image_cached_count = 0;
            model.runtime_image_error = null;
            model.last_runtime_image_cache_clear_reason = result.reason;
            model.last_runtime_image_cache_released_count = result.released_count;
            model.last_runtime_image_budget_released_count = 0;
        },
        .runtime_image_cache_budget_selected => |requested_budget| {
            const budget = runtime_image.boundedCacheBudget(requested_budget);
            model.runtime_image_cache_budget_requested = if (budget == model.runtime_image_cache_budget)
                null
            else
                budget;
        },
        .runtime_image_cache_budget_applied => |result| {
            model.runtime_image_cache_budget = runtime_image.boundedCacheBudget(result.budget);
            model.runtime_image_cache_budget_requested = null;
            model.runtime_image_cached_count = @min(result.cached_count, model.runtime_image_cache_budget);
            if (!result.visible_resource_retained) {
                model.runtime_image_loaded = false;
                model.runtime_image_cache_hit = false;
            }
            model.last_runtime_image_cache_clear_reason = null;
            model.last_runtime_image_budget_released_count = result.released_count;
        },
        .demo_navigation_selected => |index| {
            const next_index = @min(index, 2);
            if (next_index != model.demo_navigation_index) {
                model.demo_navigation_index = next_index;
                model.demo_dialog_open = false;
                model.demo_sort_expanded = false;
                model.demo_menu_expanded = false;
                if (model.activeTextInput()) |input| input.blur();
                model.active_text_input = null;
            }
        },
        .demo_tree_toggled => |index| {
            if (index < 64) model.demo_tree_expanded_mask ^= @as(u64, 1) << @intCast(index);
        },
        .demo_tree_selected => |index| model.demo_tree_selected_index = index,
        .demo_accordion_expanded => |mask| model.demo_accordion_expanded_mask = mask & 0b111,
        .demo_density_selected => |index| model.demo_density_index = @min(index, 2),
        .demo_filter_toggled => |index| {
            if (index < 4) model.demo_filter_mask ^= @as(u64, 1) << @intCast(index);
        },
        .demo_sort_selected => |index| model.demo_sort_index = @min(index, 2),
        .demo_sort_expanded => |expanded| {
            model.demo_sort_expanded = expanded;
            if (expanded) model.demo_menu_expanded = false;
        },
        .demo_tab_selected => |index| model.demo_tab_index = @min(index, 2),
        .demo_menu_expanded => |expanded| {
            model.demo_menu_expanded = expanded;
            if (expanded) model.demo_sort_expanded = false;
        },
        .demo_menu_item_activated => |index| {
            model.demo_menu_action_index = @min(index, 2);
            model.demo_menu_activation_count += 1;
            model.demo_menu_expanded = false;
        },
        .demo_virtual_list_selected => |index| model.demo_virtual_list_selected_index = @min(index, 999),
        .demo_data_table_row_selected => |index| model.demo_data_table_selected_row = @min(index, 17),
        .demo_data_table_page_selected => |page| model.demo_data_table_page = @min(page, 2),
        .demo_data_table_sorted => |sort| {
            model.demo_data_table_sort_column = @min(sort.column_index, 3);
            model.demo_data_table_sort_descending = sort.descending;
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

test "retry count action clamps controlled stepper state" {
    const std = @import("std");
    var model: Model = .{};
    update(&model, .{ .demo_retry_count_changed = 7 });
    try std.testing.expectEqual(@as(i32, 7), model.demo_retry_count);
    update(&model, .{ .demo_retry_count_changed = -4 });
    try std.testing.expectEqual(@as(i32, 0), model.demo_retry_count);
    update(&model, .{ .demo_retry_count_changed = 99 });
    try std.testing.expectEqual(@as(i32, 10), model.demo_retry_count);
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

    try std.testing.expectEqual(@as(usize, 255), model.application_name_input.length);
    try std.testing.expect(std.unicode.utf8ValidateSlice(model.text()));
}

test "text submission remains controlled and page navigation ends editing" {
    const std = @import("std");
    var model: Model = .{};

    update(&model, .{ .text_input_focus_changed = .application_name });
    update(&model, .text_submitted);
    update(&model, .{ .demo_navigation_selected = 2 });

    try std.testing.expectEqual(@as(?text_edit.Target, null), model.active_text_input);
    try std.testing.expectEqual(@as(u32, 1), model.application_name_input.submission_count);
    try std.testing.expectEqual(@as(u8, 2), model.demo_navigation_index);
}

test "page navigation is bounded and closes page-local interaction state" {
    const std = @import("std");
    var model: Model = .{
        .demo_dialog_open = true,
        .demo_sort_expanded = true,
        .demo_menu_expanded = true,
    };
    update(&model, .{ .text_input_focus_changed = .search });

    update(&model, .{ .demo_navigation_selected = 99 });

    try std.testing.expectEqual(@as(u8, 2), model.demo_navigation_index);
    try std.testing.expect(!model.demo_dialog_open);
    try std.testing.expect(!model.demo_sort_expanded);
    try std.testing.expect(!model.demo_menu_expanded);
    try std.testing.expectEqual(@as(?text_edit.Target, null), model.active_text_input);
}

test "tree expansion and selection remain controlled by the model" {
    const std = @import("std");
    var model: Model = .{};
    update(&model, .{ .demo_tree_toggled = 0 });
    try std.testing.expectEqual(@as(u64, 0b10), model.demo_tree_expanded_mask);
    update(&model, .{ .demo_tree_selected = 4 });
    try std.testing.expectEqual(@as(u8, 4), model.demo_tree_selected_index);
}

test "accordion expansion mask is reducer controlled and bounded" {
    const std = @import("std");
    var model: Model = .{};
    update(&model, .{ .demo_accordion_expanded = 0b100 });
    try std.testing.expectEqual(@as(u64, 0b100), model.demo_accordion_expanded_mask);
    update(&model, .{ .demo_accordion_expanded = std.math.maxInt(u64) });
    try std.testing.expectEqual(@as(u64, 0b111), model.demo_accordion_expanded_mask);
}

test "radio selection remains controlled and bounded" {
    const std = @import("std");
    var model: Model = .{};
    update(&model, .{ .demo_density_selected = 2 });
    try std.testing.expectEqual(@as(u8, 2), model.demo_density_index);
    update(&model, .{ .demo_density_selected = 99 });
    try std.testing.expectEqual(@as(u8, 2), model.demo_density_index);
}

test "filter chip selection mask is reducer controlled and bounded" {
    const std = @import("std");
    var model: Model = .{};
    update(&model, .{ .demo_filter_toggled = 1 });
    try std.testing.expectEqual(@as(u64, 0b0111), model.demo_filter_mask);
    update(&model, .{ .demo_filter_toggled = 0 });
    try std.testing.expectEqual(@as(u64, 0b0110), model.demo_filter_mask);
    update(&model, .{ .demo_filter_toggled = 99 });
    try std.testing.expectEqual(@as(u64, 0b0110), model.demo_filter_mask);
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
    try std.testing.expectEqual(@as(usize, 0), model.application_name_input.length);
    try std.testing.expectEqual(@as(usize, 0), model.application_name_input.cursor);
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
    try std.testing.expectEqual(@as(usize, 0), model.application_name_input.composition_length);
}

test "editing actions route to the active text target" {
    const std = @import("std");
    var model: Model = .{};
    update(&model, .{ .text_inserted = "应用" });
    update(&model, .{ .text_input_focus_changed = .search });
    update(&model, .{ .text_inserted = "日志" });
    update(&model, .text_select_all);
    update(&model, .{ .text_inserted = "项目" });

    try std.testing.expectEqualStrings("应用", model.text());
    try std.testing.expectEqualStrings("项目", model.searchText());
    try std.testing.expect(model.isTextInputActive(.search));

    update(&model, .{ .text_cleared = .search });
    try std.testing.expectEqualStrings("", model.searchText());
    try std.testing.expectEqualStrings("应用", model.text());
}

test "keyboard navigation requests are frame-latched" {
    const std = @import("std");
    var model: Model = .{};
    update(&model, .focus_previous_requested);
    update(&model, .focused_control_activate_requested);
    update(&model, .focused_control_right_requested);
    update(&model, .focused_control_home_requested);
    update(&model, .focused_control_end_requested);

    try std.testing.expect(model.focus_previous_requested);
    try std.testing.expect(model.focused_control_activate_requested);
    try std.testing.expect(model.focused_control_right_requested);
    try std.testing.expect(model.focused_control_home_requested);
    try std.testing.expect(model.focused_control_end_requested);
    update(&model, .input_consumed);
    try std.testing.expect(!model.focus_previous_requested);
    try std.testing.expect(!model.focused_control_activate_requested);
    try std.testing.expect(!model.focused_control_right_requested);
    try std.testing.expect(!model.focused_control_home_requested);
    try std.testing.expect(!model.focused_control_end_requested);
}

test "menu activation is bounded and closes the controlled menu" {
    const std = @import("std");
    var model: Model = .{};
    update(&model, .{ .demo_menu_expanded = true });
    update(&model, .{ .demo_menu_item_activated = 99 });
    try std.testing.expectEqual(@as(u8, 2), model.demo_menu_action_index);
    try std.testing.expectEqual(@as(u32, 1), model.demo_menu_activation_count);
    try std.testing.expect(!model.demo_menu_expanded);
}

test "select and menu popups remain mutually exclusive" {
    const std = @import("std");
    var model: Model = .{};
    update(&model, .{ .demo_sort_expanded = true });
    try std.testing.expect(model.demo_sort_expanded);
    update(&model, .{ .demo_menu_expanded = true });
    try std.testing.expect(model.demo_menu_expanded);
    try std.testing.expect(!model.demo_sort_expanded);
    update(&model, .{ .demo_sort_expanded = true });
    try std.testing.expect(model.demo_sort_expanded);
    try std.testing.expect(!model.demo_menu_expanded);
}

test "virtual list selection remains bounded to the demo data set" {
    const std = @import("std");
    var model: Model = .{};
    update(&model, .{ .demo_virtual_list_selected = 487 });
    try std.testing.expectEqual(@as(u16, 487), model.demo_virtual_list_selected_index);
    update(&model, .{ .demo_virtual_list_selected = 65_535 });
    try std.testing.expectEqual(@as(u16, 999), model.demo_virtual_list_selected_index);
}

test "data table selection and sort remain bounded" {
    const std = @import("std");
    var model: Model = .{};
    update(&model, .{ .demo_data_table_row_selected = 4 });
    try std.testing.expectEqual(@as(u8, 4), model.demo_data_table_selected_row);
    update(&model, .{ .demo_data_table_row_selected = 99 });
    try std.testing.expectEqual(@as(u8, 17), model.demo_data_table_selected_row);
    update(&model, .{ .demo_data_table_page_selected = 99 });
    try std.testing.expectEqual(@as(u8, 2), model.demo_data_table_page);
    update(&model, .{ .demo_data_table_sorted = .{ .column_index = 99, .descending = true } });
    try std.testing.expectEqual(@as(u8, 3), model.demo_data_table_sort_column);
    try std.testing.expect(model.demo_data_table_sort_descending);
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

/// Reducer tests and programmatic actions retain the application-name field as
/// the compatibility target when no visual field owns focus. Platform input
/// always has an active target because the keyboard is only shown on focus.
fn editingInput(model: *Model) *@import("text_edit.zig").State {
    return model.activeTextInput() orelse &model.application_name_input;
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

test "runtime image loading preserves the last success across failures" {
    const std = @import("std");
    var model: Model = .{};
    update(&model, .platform_runtime_image_load_requested);
    update(&model, .{ .platform_runtime_image_load_started = 31 });
    update(&model, .{ .platform_runtime_image_load_progress = .{
        .request_id = 31,
        .bytes_received = 4096,
    } });
    try std.testing.expect(model.runtime_image_load_pending);
    try std.testing.expectEqual(@as(u64, 4096), model.runtime_image_bytes_received);

    update(&model, .{ .platform_runtime_image_load_succeeded = .{
        .request_id = 31,
        .encoded_bytes = 12_266,
        .resource = .runtime_2,
        .width = 128,
        .height = 64,
        .cache_hit = false,
        .cached_count = 3,
    } });
    try std.testing.expect(model.runtime_image_loaded);
    try std.testing.expectEqual(@as(u32, 128), model.runtime_image_width);
    try std.testing.expectEqual(@import("../assets/image_catalog.zig").Resource.runtime_2, model.runtime_image_resource);
    try std.testing.expectEqual(@as(u8, 3), model.runtime_image_cached_count);

    update(&model, .{ .platform_runtime_image_load_started = 32 });
    update(&model, .{ .platform_runtime_image_load_succeeded = .{
        .request_id = 32,
        .encoded_bytes = 12_266,
        .resource = .runtime_2,
        .width = 128,
        .height = 64,
        .cache_hit = true,
        .cached_count = 3,
    } });
    try std.testing.expect(model.runtime_image_cache_hit);

    update(&model, .{ .platform_runtime_image_load_started = 33 });
    update(&model, .{ .platform_runtime_image_load_failed = .{
        .request_id = 33,
        .error_kind = .invalid_data,
    } });
    try std.testing.expect(!model.runtime_image_load_pending);
    try std.testing.expect(model.runtime_image_loaded);
    try std.testing.expectEqual(@as(u32, 128), model.runtime_image_width);
    try std.testing.expect(model.runtime_image_error == .invalid_data);
}

test "runtime image cache clearing records reason and releases visible state" {
    const std = @import("std");
    var model: Model = .{
        .runtime_image_loaded = true,
        .runtime_image_cached_count = 3,
        .runtime_image_cache_hit = true,
    };
    update(&model, .{ .runtime_image_cache_clear_requested = .memory_pressure });
    try std.testing.expect(model.runtime_image_cache_clear_requested);
    update(&model, .{ .runtime_image_cache_cleared = .{
        .reason = .memory_pressure,
        .released_count = 3,
    } });
    try std.testing.expect(!model.runtime_image_cache_clear_requested);
    try std.testing.expect(!model.runtime_image_loaded);
    try std.testing.expectEqual(@as(u8, 0), model.runtime_image_cached_count);
    try std.testing.expectEqual(@as(u8, 3), model.last_runtime_image_cache_released_count);
    try std.testing.expect(model.last_runtime_image_cache_clear_reason == .memory_pressure);
}

test "runtime image cache budget is bounded and only drops an evicted preview" {
    const std = @import("std");
    var model: Model = .{
        .runtime_image_loaded = true,
        .runtime_image_cached_count = 4,
    };
    update(&model, .{ .runtime_image_cache_budget_selected = 2 });
    try std.testing.expectEqual(@as(?u8, 2), model.runtime_image_cache_budget_requested);
    update(&model, .{ .runtime_image_cache_budget_applied = .{
        .budget = 2,
        .released_count = 2,
        .cached_count = 2,
        .visible_resource_retained = true,
    } });
    try std.testing.expectEqual(@as(u8, 2), model.runtime_image_cache_budget);
    try std.testing.expectEqual(@as(u8, 2), model.runtime_image_cached_count);
    try std.testing.expect(model.runtime_image_loaded);

    update(&model, .{ .runtime_image_cache_budget_selected = 0 });
    try std.testing.expectEqual(@as(?u8, 1), model.runtime_image_cache_budget_requested);
    update(&model, .{ .runtime_image_cache_budget_applied = .{
        .budget = 1,
        .released_count = 1,
        .cached_count = 1,
        .visible_resource_retained = false,
    } });
    try std.testing.expectEqual(@as(u8, 1), model.runtime_image_cache_budget);
    try std.testing.expect(!model.runtime_image_loaded);
    try std.testing.expectEqual(@as(u8, 1), model.last_runtime_image_budget_released_count);
}
