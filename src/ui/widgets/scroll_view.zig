const clay = @import("zclay");

pub const Config = struct {
    id: []const u8,
    height: f32,
    child_gap: u16 = 8,
    padding: u16 = 12,
    background_color: clay.Color = .{ 22, 34, 53, 255 },
};

/// Returns a Clay declaration so callers can place arbitrary child UI inside.
pub fn declaration(config: Config) clay.ElementDeclaration {
    return .{
        .id = .ID(config.id),
        .layout = .{
            .sizing = .{ .w = .grow, .h = .fixed(config.height) },
            .padding = .all(config.padding),
            .child_gap = config.child_gap,
            .direction = .top_to_bottom,
        },
        .background_color = config.background_color,
        .corner_radius = .all(10),
        .clip = .{ .vertical = true },
    };
}
