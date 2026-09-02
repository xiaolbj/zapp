const clay = @import("zclay");
const semantics = @import("../semantics.zig");
const theme = @import("../theme.zig");

pub const Config = struct {
    font_size: u16 = 16,
    color: clay.Color = theme.controls.text,
    wrap_mode: clay.TextElementConfigWrapMode = .none,
    semantic_id: ?clay.ElementId = null,
    semantic_role: semantics.Role = .text,
    semantic_registry: ?*semantics.Registry = null,
};

pub fn draw(text: []const u8, config: Config) void {
    if (config.semantic_id) |id| {
        if (config.semantic_registry) |registry| _ = registry.add(.{
            .element_id = id.id,
            .role = config.semantic_role,
            .label = text,
        });
        clay.UI()(.{
            .id = id,
            .layout = .{ .sizing = .fit },
        })({
            drawText(text, config);
        });
        return;
    }
    drawText(text, config);
}

fn drawText(text: []const u8, config: Config) void {
    clay.text(text, .{
        .font_size = config.font_size,
        .color = config.color,
        .wrap_mode = config.wrap_mode,
    });
}
