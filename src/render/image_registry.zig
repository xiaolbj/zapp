const std = @import("std");
const sokol = @import("sokol");
const catalog = @import("../assets/image_catalog.zig");
const image_decode = @import("image_decode.zig");

const sg = sokol.gfx;

pub const Texture = struct {
    view: sg.View,
    sampler: sg.Sampler,
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
            if (!self.load(resource)) {
                self.shutdown();
                return false;
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

    fn load(self: *Registry, resource: catalog.Resource) bool {
        const item = catalog.descriptor(resource);
        var decoded = image_decode.decode(item.encoded_bytes) catch return false;
        defer decoded.deinit();
        if (decoded.width != item.pixel_width or decoded.height != item.pixel_height) return false;

        var data: sg.ImageData = .{};
        data.mip_levels[0] = .{ .ptr = decoded.pixels, .size = decoded.byte_count };
        const entry = &self.entries[index(resource)];
        entry.image = sg.makeImage(.{
            .width = @intCast(decoded.width),
            .height = @intCast(decoded.height),
            .pixel_format = .RGBA8,
            .data = data,
            .label = item.label,
        });
        if (entry.image.id == 0) return false;
        entry.view = sg.makeView(.{
            .texture = .{ .image = entry.image },
            .label = item.label,
        });
        if (entry.view.id == 0) {
            sg.destroyImage(entry.image);
            entry.* = .{};
            return false;
        }
        return true;
    }
};

fn index(resource: catalog.Resource) usize {
    return @intFromEnum(resource);
}

test "empty registry does not resolve GPU textures" {
    const registry: Registry = .{};
    try std.testing.expect(registry.resolve(.demo_hero) == null);
}
