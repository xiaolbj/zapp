const clay = @import("zclay");

pub const Config = struct {
    id: []const u8,
    sizing: clay.Sizing = .grow,
    padding: u16 = 24,
    child_gap: u16 = 12,
    direction: clay.LayoutDirection = .top_to_bottom,
    background_color: clay.Color = .{ 31, 45, 70, 255 },
    corner_radius: f32 = 12,
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
    };
}
