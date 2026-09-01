const clay = @import("zclay");
const semantics = @import("../semantics.zig");
const theme = @import("../theme.zig");

pub const Config = struct {
    id: []const u8,
    height: f32,
    child_gap: u16 = theme.controls.gap_small,
    padding: u16 = 12,
    background_color: clay.Color = theme.controls.scroll_surface,
    semantic_label: ?[]const u8 = null,
    semantic_registry: ?*semantics.Registry = null,
};

/// Returns a Clay declaration so callers can place arbitrary child UI inside.
pub fn declaration(config: Config) clay.ElementDeclaration {
    const id = clay.ElementId.ID(config.id);
    if (config.semantic_label) |semantic_label| {
        if (config.semantic_registry) |registry| _ = registry.add(.{
            .element_id = id.id,
            .role = .list,
            .label = semantic_label,
        });
    }
    return .{
        .id = id,
        .layout = .{
            .sizing = .{ .w = .grow, .h = .fixed(config.height) },
            .padding = .all(config.padding),
            .child_gap = config.child_gap,
            .direction = .top_to_bottom,
        },
        .background_color = config.background_color,
        .corner_radius = .all(theme.controls.radius_medium),
        .clip = .{ .vertical = true },
    };
}
