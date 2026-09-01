const clay = @import("zclay");
const theme = @import("../theme.zig");

pub const Config = struct {
    thickness: f32 = 1,
    color: clay.Color = theme.controls.divider,
};

pub fn draw(config: Config) void {
    clay.UI()(.{
        .layout = .{ .sizing = .{ .w = .grow, .h = .fixed(config.thickness) } },
        .background_color = config.color,
    })({});
}
