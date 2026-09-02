const frame_metrics = @import("../performance/frame_metrics.zig");
const platform = @import("../platform/platform.zig");
const runtime_image = @import("../assets/runtime_image.zig");
const text_edit = @import("text_edit.zig");

pub const Model = struct {
    frame_count: u64 = 0,
    elapsed_seconds: f64 = 0,
    viewport_width: i32 = 1280,
    viewport_height: i32 = 720,
    dpi_scale: f32 = 1,
    pointer_x: f32 = 0,
    pointer_y: f32 = 0,
    pointer_down: bool = false,
    pointer_pressed: bool = false,
    pointer_released: bool = false,
    scroll_delta_x: f32 = 0,
    scroll_delta_y: f32 = 0,
    semantic_scroll_element_id: ?u32 = null,
    semantic_scroll_direction: i8 = 0,
    frame_delta_seconds: f32 = 0,
    performance: frame_metrics.Snapshot = .{},
    last_native_crash: ?platform.NativeCrashReport = null,
    crash_report_export_pending: bool = false,
    crash_report_export_attempted: bool = false,
    crash_report_export_chooser_opened: bool = false,
    last_crash_report_export_request_id: platform.RequestId = 0,
    primary_button_presses: u32 = 0,
    demo_checkbox_checked: bool = false,
    demo_switch_checked: bool = true,
    demo_progress: f32 = 0.35,
    demo_volume: f32 = 0.65,
    demo_retry_count: i32 = 3,
    demo_dialog_open: bool = false,
    demo_dialog_confirmations: u32 = 0,
    back_requested: bool = false,
    focus_next_requested: bool = false,
    focus_previous_requested: bool = false,
    focused_control_activate_requested: bool = false,
    focused_control_up_requested: bool = false,
    focused_control_down_requested: bool = false,
    focused_control_left_requested: bool = false,
    focused_control_right_requested: bool = false,
    focused_control_home_requested: bool = false,
    focused_control_end_requested: bool = false,
    active_text_input: ?text_edit.Target = null,
    application_name_input: text_edit.State = .{},
    search_input: text_edit.State = .{},
    permission_request_pending: bool = false,
    last_permission_request_id: platform.RequestId = 0,
    last_permission: ?platform.Permission = null,
    last_permission_granted: bool = false,
    file_picker_pending: bool = false,
    last_file_request_id: platform.RequestId = 0,
    selected_file_uri_buffer: [platform.max_file_uri_bytes]u8 = @splat(0),
    selected_file_uri_length: usize = 0,
    file_selection_cancel_count: u32 = 0,
    file_read_pending: bool = false,
    last_file_read_request_id: platform.RequestId = 0,
    file_preview_buffer: [platform.max_file_preview_bytes]u8 = @splat(0),
    file_preview_length: usize = 0,
    file_preview_truncated: bool = false,
    file_read_error: ?platform.FileReadError = null,
    file_display_name_buffer: [platform.max_file_display_name_bytes]u8 = @splat(0),
    file_display_name_length: usize = 0,
    file_mime_type_buffer: [platform.max_file_mime_type_bytes]u8 = @splat(0),
    file_mime_type_length: usize = 0,
    file_size: u64 = 0,
    file_size_known: bool = false,
    file_stream_pending: bool = false,
    file_stream_cancel_pending: bool = false,
    file_stream_completed: bool = false,
    file_stream_cancelled: bool = false,
    last_file_stream_request_id: platform.RequestId = 0,
    file_stream_bytes_consumed: u64 = 0,
    file_stream_chunk_count: u64 = 0,
    file_stream_hash: u64 = 14695981039346656037,
    file_stream_error: ?platform.FileReadError = null,
    runtime_image_load_pending: bool = false,
    runtime_image_cancel_pending: bool = false,
    runtime_image_loaded: bool = false,
    last_runtime_image_request_id: platform.RequestId = 0,
    runtime_image_bytes_received: u64 = 0,
    runtime_image_width: u32 = 0,
    runtime_image_height: u32 = 0,
    runtime_image_error: ?runtime_image.LoadFailure = null,
    demo_navigation_index: u8 = 0,
    demo_tree_expanded_mask: u64 = 0b11,
    demo_tree_selected_index: u8 = 2,
    demo_accordion_expanded_mask: u64 = 0b001,
    demo_density_index: u8 = 1,
    demo_filter_mask: u64 = 0b0101,
    demo_sort_index: u8 = 0,
    demo_sort_expanded: bool = false,
    demo_tab_index: u8 = 0,
    demo_menu_expanded: bool = false,
    demo_menu_action_index: u8 = 0,
    demo_menu_activation_count: u32 = 0,
    demo_virtual_list_selected_index: u16 = 0,
    demo_data_table_selected_row: u8 = 0,
    demo_data_table_page: u8 = 0,
    demo_data_table_sort_column: u8 = 0,
    demo_data_table_sort_descending: bool = false,
    suspended: bool = false,

    pub fn text(self: *const Model) []const u8 {
        return self.application_name_input.text();
    }

    pub fn searchText(self: *const Model) []const u8 {
        return self.search_input.text();
    }

    pub fn textInput(self: *Model, target: text_edit.Target) *text_edit.State {
        return switch (target) {
            .application_name => &self.application_name_input,
            .search => &self.search_input,
        };
    }

    pub fn textInputConst(self: *const Model, target: text_edit.Target) *const text_edit.State {
        return switch (target) {
            .application_name => &self.application_name_input,
            .search => &self.search_input,
        };
    }

    pub fn activeTextInput(self: *Model) ?*text_edit.State {
        return self.textInput(self.active_text_input orelse return null);
    }

    pub fn activeTextInputConst(self: *const Model) ?*const text_edit.State {
        return self.textInputConst(self.active_text_input orelse return null);
    }

    pub fn isTextInputActive(self: *const Model, target: text_edit.Target) bool {
        return self.active_text_input == target;
    }

    pub fn hasTextSelection(self: *const Model) bool {
        return self.application_name_input.hasSelection();
    }

    pub fn selectionStart(self: *const Model) usize {
        return self.application_name_input.selectionStart();
    }

    pub fn selectionEnd(self: *const Model) usize {
        return self.application_name_input.selectionEnd();
    }

    pub fn selectedText(self: *const Model) []const u8 {
        const active = self.activeTextInputConst() orelse &self.application_name_input;
        return active.selectedText();
    }

    pub fn textComposition(self: *const Model) []const u8 {
        return self.application_name_input.composition();
    }

    pub fn selectedFileUri(self: *const Model) []const u8 {
        return self.selected_file_uri_buffer[0..self.selected_file_uri_length];
    }

    pub fn filePreview(self: *const Model) []const u8 {
        return self.file_preview_buffer[0..self.file_preview_length];
    }

    pub fn fileDisplayName(self: *const Model) []const u8 {
        return self.file_display_name_buffer[0..self.file_display_name_length];
    }

    pub fn fileMimeType(self: *const Model) []const u8 {
        return self.file_mime_type_buffer[0..self.file_mime_type_length];
    }
};
