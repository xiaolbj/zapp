const clay = @import("zclay");

pub const Config = struct {
    thickness: f32 = 1,
    color: clay.Color = .{ 58, 76, 104, 255 },
};

pub fn draw(config: Config) void {
    clay.UI()(.{
        .layout = .{ .sizing = .{ .w = .grow, .h = .fixed(config.thickness) } },
        .background_color = config.color,
    })({});
}
