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

pub const Action = union(enum) {
    tick: f64,
    resized: Viewport,
    pointer_changed: Pointer,
    input_consumed,
    primary_button_pressed,
    suspended,
    resumed,
};
