const clay = @import("zclay");
const semantics = @import("../semantics.zig");
const image_catalog = @import("../../assets/image_catalog.zig");

pub const Resource = image_catalog.Resource;

pub const Fit = enum(u8) {
    stretch,
    contain,
    cover,
};

/// Platform-neutral reference carried through Clay's opaque image_data field.
/// Sources must outlive the frame that references them.
pub const Source = struct {
    resource: Resource,
    pixel_width: f32,
    pixel_height: f32,
    fit: Fit = .cover,
};

pub const Config = struct {
    id: []const u8,
    source: *const Source,
    width: f32,
    height: f32,
    corner_radius: f32 = 0,
    tint: clay.Color = .{ 0, 0, 0, 0 },
    semantic_label: []const u8,
    semantic_registry: ?*semantics.Registry = null,
};

/// Emits a Clay image command while leaving texture ownership and fit math to
/// the renderer. ImageView is intentionally non-interactive.
pub fn draw(config: Config) void {
    const id = clay.ElementId.ID(config.id);
    if (config.semantic_registry) |registry| _ = registry.add(.{
        .element_id = id.id,
        .role = .image,
        .label = config.semantic_label,
    });
    clay.UI()(.{
        .id = id,
        .layout = .{ .sizing = .{
            .w = .fixed(config.width),
            .h = .fixed(config.height),
        } },
        .background_color = config.tint,
        .corner_radius = .all(config.corner_radius),
        .image = .{ .image_data = config.source },
    })({});
}

test "image sources keep resource identity intrinsic size and fit" {
    const std = @import("std");
    const source: Source = .{
        .resource = .demo_hero,
        .pixel_width = 128,
        .pixel_height = 64,
        .fit = .contain,
    };
    try std.testing.expectEqual(Resource.demo_hero, source.resource);
    try std.testing.expectEqual(@as(f32, 2), source.pixel_width / source.pixel_height);
    try std.testing.expectEqual(Fit.contain, source.fit);
}
