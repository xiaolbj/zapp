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
    primary_button_presses: u32 = 0,
    suspended: bool = false,
};
