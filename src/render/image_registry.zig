const std = @import("std");
const sokol = @import("sokol");
const catalog = @import("../assets/image_catalog.zig");
const image_cache = @import("image_cache.zig");
const image_decode = @import("image_decode.zig");

const sg = sokol.gfx;

comptime {
    std.debug.assert(image_cache.capacity == catalog.runtime_resource_count);
}

pub const Texture = struct {
    view: sg.View,
    sampler: sg.Sampler,
};

pub const CacheResult = struct {
    resource: catalog.Resource,
    width: u32,
    height: u32,
    cache_hit: bool,
    cached_count: u8,
};

pub const BudgetResult = struct {
    budget: u8,
    released_count: u8,
    cached_count: u8,
};

pub const CacheError = error{
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
    cache: image_cache.Index = .{},
    cache_budget: u8 = @intCast(image_cache.capacity),

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
        self.cache.reset();
    }

    pub fn resolve(self: *const Registry, resource: catalog.Resource) ?Texture {
        const entry = self.entries[index(resource)];
        if (entry.view.id == 0 or self.sampler.id == 0) return null;
        return .{ .view = entry.view, .sampler = self.sampler };
    }

    pub fn clearRuntime(self: *Registry) u8 {
        const released_count: u8 = @intCast(self.cache.count());
        inline for (0..catalog.runtime_resource_count) |slot| {
            const entry = &self.entries[index(catalog.runtimeResource(slot))];
            destroyEntry(entry.*);
            entry.* = .{};
        }
        self.cache.reset();
        return released_count;
    }

    pub fn setRuntimeCacheBudget(self: *Registry, requested_budget: u8) BudgetResult {
        const budget = image_cache.boundedBudget(requested_budget);
        const trimmed = self.cache.trimTo(budget);
        for (trimmed.items()) |slot| {
            const entry = &self.entries[index(catalog.runtimeResource(slot))];
            destroyEntry(entry.*);
            entry.* = .{};
        }
        self.cache_budget = @intCast(budget);
        return .{
            .budget = self.cache_budget,
            .released_count = @intCast(trimmed.count),
            .cached_count = @intCast(self.cache.count()),
        };
    }

    /// Replaces a dynamic slot only after decode and both GPU objects succeed.
    /// A failed update leaves the previously visible texture untouched.
    pub fn cacheEncoded(
        self: *Registry,
        encoded_bytes: []const u8,
    ) CacheError!CacheResult {
        const digest = image_cache.contentDigest(encoded_bytes);
        if (self.cache.lookup(digest)) |hit| return .{
            .resource = catalog.runtimeResource(hit.slot),
            .width = hit.width,
            .height = hit.height,
            .cache_hit = true,
            .cached_count = @intCast(self.cache.count()),
        };

        const slot = self.cache.victim(self.cache_budget);
        const resource = catalog.runtimeResource(slot);
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
        self.cache.commit(slot, digest, decoded.width, decoded.height);
        destroyEntry(previous);
        return .{
            .resource = resource,
            .width = decoded.width,
            .height = decoded.height,
            .cache_hit = false,
            .cached_count = @intCast(self.cache.count()),
        };
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
    var registry: Registry = .{};
    try std.testing.expect(registry.resolve(.demo_hero) == null);
    inline for (0..catalog.runtime_resource_count) |slot| {
        try std.testing.expect(registry.resolve(catalog.runtimeResource(slot)) == null);
    }
    try std.testing.expectEqual(@as(u8, 0), registry.clearRuntime());
    const budget_result = registry.setRuntimeCacheBudget(0);
    try std.testing.expectEqual(@as(u8, 1), budget_result.budget);
    try std.testing.expectEqual(@as(u8, 0), budget_result.released_count);
}
