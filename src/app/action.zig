pub const Viewport = struct {
    width: i32,
    height: i32,
    dpi_scale: f32,
};

pub const Pointer = struct {
    x: f32,
    y: f32,
    down: bool,
};

pub const ScrollDelta = struct {
    x: f32,
    y: f32,
};

pub const SemanticScrollRequest = struct {
    element_id: u32,
    direction: i8,
};

pub const TextCursorMove = struct {
    direction: i8,
    selecting: bool,
};

pub const TextCursorSet = struct {
    position: usize,
    selecting: bool,
};

pub const Action = union(enum) {
    tick: f64,
    performance_updated: frame_metrics.Snapshot,
    platform_native_crash_recovered: platform.NativeCrashReport,
    platform_crash_report_export_requested,
    platform_crash_report_export_started: platform.RequestId,
    platform_crash_report_export_result: platform.CrashReportExportResult,
    resized: Viewport,
    pointer_changed: Pointer,
    scroll_changed: ScrollDelta,
    semantic_scroll_requested: SemanticScrollRequest,
    input_consumed,
    primary_button_pressed,
    demo_checkbox_toggled,
    demo_switch_toggled,
    demo_progress_incremented,
    demo_volume_changed: f32,
    demo_dialog_opened,
    demo_dialog_closed,
    demo_dialog_confirmed,
    back_requested,
    focus_next_requested,
    focus_previous_requested,
    focused_control_activate_requested,
    focused_control_up_requested,
    focused_control_down_requested,
    focused_control_left_requested,
    focused_control_right_requested,
    text_field_focus_changed: bool,
    text_inserted: []const u8,
    text_backspace,
    text_delete_selection,
    text_cursor_moved: TextCursorMove,
    text_cursor_set: TextCursorSet,
    text_cursor_home: bool,
    text_cursor_end: bool,
    text_select_all,
    text_composition_changed: []const u8,
    text_composition_committed: []const u8,
    text_composition_cancelled,
    text_submitted,
    platform_permission_requested: platform.Permission,
    platform_permission_result: platform.PermissionResult,
    platform_file_picker_requested,
    platform_file_selected: platform.FileSelection,
    platform_file_selection_cancelled: platform.RequestId,
    platform_file_read_completed: platform.FileReadResult,
    platform_file_read_failed: platform.FileReadFailure,
    platform_file_stream_requested,
    platform_file_stream_started: platform.RequestId,
    platform_file_stream_cancel_requested,
    platform_file_stream_chunk: platform.FileStreamChunk,
    platform_file_stream_completed: platform.FileStreamTerminal,
    platform_file_stream_failed: platform.FileReadFailure,
    platform_file_stream_cancelled: platform.FileStreamTerminal,
    demo_navigation_selected: u8,
    demo_tree_toggled: u8,
    demo_tree_selected: u8,
    demo_density_selected: u8,
    suspended,
    resumed,
};
const frame_metrics = @import("../performance/frame_metrics.zig");
const platform = @import("../platform/platform.zig");
