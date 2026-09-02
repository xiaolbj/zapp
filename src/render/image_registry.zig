const std = @import("std");
const sokol = @import("sokol");
const catalog = @import("../assets/image_catalog.zig");
const image_decode = @import("image_decode.zig");

const sg = sokol.gfx;

pub const Texture = struct {
    view: sg.View,
    sampler: sg.Sampler,
};

pub const Dimensions = struct {
    width: u32,
    height: u32,
};

pub const ReplaceError = error{
    ImmutableResource,
    InvalidData,
    LimitExceeded,
    GpuUploadFailed,
};

const Entry = struct {
    image: sg.Image = .{},
    view: sg.View = .{},
};

pub const Registry = struct {
    entries: [catalog.resource_count]Entry = @splat(.{}),
    sampler: sg.Sampler = .{},

    pub fn setup(self: *Registry) bool {
        self.shutdown();
        self.sampler = sg.makeSampler(.{
            .min_filter = .LINEAR,
            .mag_filter = .LINEAR,
            .wrap_u = .CLAMP_TO_EDGE,
            .wrap_v = .CLAMP_TO_EDGE,
            .label = "zapp-image-sampler",
        });
        if (self.sampler.id == 0) return false;

        inline for (std.meta.fields(catalog.Resource)) |field| {
            const resource: catalog.Resource = @enumFromInt(field.value);
            if (comptime catalog.descriptor(resource)) |item| {
                if (!self.load(item)) {
                    self.shutdown();
                    return false;
                }
            }
        }
        return true;
    }

    pub fn shutdown(self: *Registry) void {
        for (&self.entries) |*entry| {
            if (entry.view.id != 0) sg.destroyView(entry.view);
            if (entry.image.id != 0) sg.destroyImage(entry.image);
            entry.* = .{};
        }
        if (self.sampler.id != 0) sg.destroySampler(self.sampler);
        self.sampler = .{};
    }

    pub fn resolve(self: *const Registry, resource: catalog.Resource) ?Texture {
        const entry = self.entries[index(resource)];
        if (entry.view.id == 0 or self.sampler.id == 0) return null;
        return .{ .view = entry.view, .sampler = self.sampler };
    }

    /// Replaces a dynamic slot only after decode and both GPU objects succeed.
    /// A failed update leaves the previously visible texture untouched.
    pub fn replaceEncoded(
        self: *Registry,
        resource: catalog.Resource,
        encoded_bytes: []const u8,
    ) ReplaceError!Dimensions {
        if (catalog.descriptor(resource) != null) return error.ImmutableResource;
        var decoded = image_decode.decode(encoded_bytes) catch |decode_error| return switch (decode_error) {
            error.LimitExceeded => error.LimitExceeded,
            else => error.InvalidData,
        };
        defer decoded.deinit();

        const replacement = createEntry(
            decoded,
            "zapp-runtime-image",
        ) catch return error.GpuUploadFailed;
        const entry = &self.entries[index(resource)];
        const previous = entry.*;
        entry.* = replacement;
        destroyEntry(previous);
        return .{ .width = decoded.width, .height = decoded.height };
    }

    fn load(self: *Registry, item: catalog.Descriptor) bool {
        var decoded = image_decode.decode(item.encoded_bytes) catch return false;
        defer decoded.deinit();
        if (decoded.width != item.pixel_width or decoded.height != item.pixel_height) return false;
        self.entries[index(item.resource)] = createEntry(decoded, item.label) catch return false;
        return true;
    }
};

fn createEntry(decoded: image_decode.DecodedImage, label: [:0]const u8) error{GpuUploadFailed}!Entry {
    var data: sg.ImageData = .{};
    data.mip_levels[0] = .{ .ptr = decoded.pixels, .size = decoded.byte_count };
    var entry: Entry = .{};
    entry.image = sg.makeImage(.{
        .width = @intCast(decoded.width),
        .height = @intCast(decoded.height),
        .pixel_format = .RGBA8,
        .data = data,
        .label = label,
    });
    if (entry.image.id == 0) return error.GpuUploadFailed;
    entry.view = sg.makeView(.{
        .texture = .{ .image = entry.image },
        .label = label,
    });
    if (entry.view.id == 0) {
        sg.destroyImage(entry.image);
        return error.GpuUploadFailed;
    }
    return entry;
}

fn destroyEntry(entry: Entry) void {
    if (entry.view.id != 0) sg.destroyView(entry.view);
    if (entry.image.id != 0) sg.destroyImage(entry.image);
}

fn index(resource: catalog.Resource) usize {
    return @intFromEnum(resource);
}

test "empty registry does not resolve GPU textures" {
    const registry: Registry = .{};
    try std.testing.expect(registry.resolve(.demo_hero) == null);
    try std.testing.expect(registry.resolve(.runtime_preview) == null);
}
