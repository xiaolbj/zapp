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

pub const Action = union(enum) {
    tick: f64,
    resized: Viewport,
    pointer_changed: Pointer,
    scroll_changed: ScrollDelta,
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
    text_field_focus_changed: bool,
    text_inserted: []const u8,
    text_backspace,
    text_submitted,
    demo_navigation_selected: u8,
    suspended,
    resumed,
};
