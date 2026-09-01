const clay = @import("zclay");
const theme = @import("../theme.zig");

pub const Config = struct {
    id: []const u8,
    sizing: clay.Sizing = .grow,
    padding: u16 = 24,
    child_gap: u16 = theme.controls.gap_medium,
    direction: clay.LayoutDirection = .top_to_bottom,
    background_color: clay.Color = theme.controls.card,
    corner_radius: f32 = theme.controls.radius_medium,
    scroll_vertical: bool = false,
};

/// Returns a declaration so the caller can compose arbitrary card content.
pub fn declaration(config: Config) clay.ElementDeclaration {
    return .{
        .id = .ID(config.id),
        .layout = .{
            .sizing = config.sizing,
            .padding = .all(config.padding),
            .child_gap = config.child_gap,
            .direction = config.direction,
        },
        .background_color = config.background_color,
        .corner_radius = .all(config.corner_radius),
        .clip = .{ .vertical = config.scroll_vertical },
    };
}
