const clay = @import("zclay");
const semantics = @import("../semantics.zig");
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
    semantic_label: ?[]const u8 = null,
    semantic_registry: ?*semantics.Registry = null,
};

/// Returns a declaration so the caller can compose arbitrary card content.
pub fn declaration(config: Config) clay.ElementDeclaration {
    const id = clay.ElementId.ID(config.id);
    if (config.semantic_label) |semantic_label| {
        if (config.semantic_registry) |registry| _ = registry.add(.{
            .element_id = id.id,
            .role = .group,
            .label = semantic_label,
            .scrollable = config.scroll_vertical,
        });
    }
    return .{
        .id = id,
        .layout = .{
            .sizing = config.sizing,
            .padding = .all(config.padding),
            .child_gap = config.child_gap,
            .direction = config.direction,
        },
        .background_color = config.background_color,
        .corner_radius = .all(config.corner_radius),
        .clip = .{
            .vertical = config.scroll_vertical,
            .child_offset = if (config.scroll_vertical)
                clay.getScrollOffset()
            else
                .{ .x = 0, .y = 0 },
        },
    };
}
