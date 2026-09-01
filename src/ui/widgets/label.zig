const clay = @import("zclay");
const theme = @import("../theme.zig");

pub const Config = struct {
    font_size: u16 = 16,
    color: clay.Color = theme.controls.text,
    wrap_mode: clay.TextElementConfigWrapMode = .none,
};

pub fn draw(text: []const u8, config: Config) void {
    clay.text(text, .{
        .font_size = config.font_size,
        .color = config.color,
        .wrap_mode = config.wrap_mode,
    });
}
