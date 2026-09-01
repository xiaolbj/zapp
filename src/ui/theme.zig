pub const Color = struct {
    r: f32,
    g: f32,
    b: f32,
    a: f32 = 1,
};

pub const Theme = struct {
    background: Color,
    surface: Color,
    primary: Color,
    text: Color,
};

pub const dark: Theme = .{
    .background = .{ .r = 0.035, .g = 0.047, .b = 0.075 },
    .surface = .{ .r = 0.075, .g = 0.094, .b = 0.135 },
    .primary = .{ .r = 0.255, .g = 0.553, .b = 0.953 },
    .text = .{ .r = 0.92, .g = 0.94, .b = 0.97 },
};
