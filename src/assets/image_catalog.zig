const std = @import("std");

pub const Resource = enum(u8) {
    demo_hero,
    activity_thumbnail,
    runtime_0,
    runtime_1,
    runtime_2,
    runtime_3,
};

pub const Descriptor = struct {
    resource: Resource,
    encoded_bytes: []const u8,
    pixel_width: u32,
    pixel_height: u32,
    label: [:0]const u8,
};

pub const resource_count = std.meta.fields(Resource).len;
pub const runtime_resource_count: usize = 4;

const demo_hero_bytes = @embedFile("../../assets/images/app-hero.png");
const activity_thumbnail_bytes = @embedFile("../../assets/images/activity-card.jpg");

pub fn descriptor(resource: Resource) ?Descriptor {
    return switch (resource) {
        .demo_hero => .{
            .resource = resource,
            .encoded_bytes = demo_hero_bytes,
            .pixel_width = 128,
            .pixel_height = 64,
            .label = "zapp-demo-hero",
        },
        .activity_thumbnail => .{
            .resource = resource,
            .encoded_bytes = activity_thumbnail_bytes,
            .pixel_width = 96,
            .pixel_height = 64,
            .label = "zapp-activity-thumbnail",
        },
        .runtime_0, .runtime_1, .runtime_2, .runtime_3 => null,
    };
}

pub fn runtimeResource(slot: usize) Resource {
    std.debug.assert(slot < runtime_resource_count);
    return @enumFromInt(@intFromEnum(Resource.runtime_0) + slot);
}

pub fn runtimeSlot(resource: Resource) ?usize {
    const value = @intFromEnum(resource);
    const first = @intFromEnum(Resource.runtime_0);
    if (value < first or value >= first + runtime_resource_count) return null;
    return value - first;
}

test "catalog owns stable encoded image metadata" {
    const item = descriptor(.demo_hero).?;
    try std.testing.expectEqual(Resource.demo_hero, item.resource);
    try std.testing.expectEqual(@as(u32, 128), item.pixel_width);
    try std.testing.expectEqual(@as(u32, 64), item.pixel_height);
    try std.testing.expect(item.encoded_bytes.len > 8);
    try std.testing.expectEqualSlices(u8, "\x89PNG\r\n\x1a\n", item.encoded_bytes[0..8]);

    const thumbnail = descriptor(.activity_thumbnail).?;
    try std.testing.expectEqual(@as(u32, 96), thumbnail.pixel_width);
    try std.testing.expectEqual(@as(u32, 64), thumbnail.pixel_height);
    try std.testing.expectEqualSlices(u8, "\xff\xd8", thumbnail.encoded_bytes[0..2]);
    inline for (0..runtime_resource_count) |slot| {
        const resource = runtimeResource(slot);
        try std.testing.expectEqual(slot, runtimeSlot(resource).?);
        try std.testing.expect(descriptor(resource) == null);
    }
    try std.testing.expect(runtimeSlot(.demo_hero) == null);
}
