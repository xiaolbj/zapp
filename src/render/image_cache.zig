const std = @import("std");

pub const capacity: usize = 4;
pub const min_budget: usize = 1;
pub const Digest = [32]u8;

pub const Entry = struct {
    valid: bool = false,
    digest: Digest = @splat(0),
    width: u32 = 0,
    height: u32 = 0,
    last_used: u64 = 0,
};

pub const Hit = struct {
    slot: usize,
    width: u32,
    height: u32,
};

pub const TrimResult = struct {
    slots: [capacity]usize = undefined,
    count: usize = 0,

    pub fn items(self: *const TrimResult) []const usize {
        return self.slots[0..self.count];
    }
};

pub fn boundedBudget(requested: usize) usize {
    return @min(@max(requested, min_budget), capacity);
}

pub fn contentDigest(encoded_bytes: []const u8) Digest {
    var result: Digest = undefined;
    std.crypto.hash.sha2.Sha256.hash(encoded_bytes, &result, .{});
    return result;
}

/// Fixed-capacity LRU metadata. GPU ownership stays in image_registry; this
/// index is committed only after the matching texture and view both exist.
pub const Index = struct {
    entries: [capacity]Entry = @splat(.{}),
    tick: u64 = 0,

    pub fn reset(self: *Index) void {
        self.* = .{};
    }

    pub fn lookup(self: *Index, digest: Digest) ?Hit {
        for (&self.entries, 0..) |*entry, slot| {
            if (entry.valid and std.mem.eql(u8, &entry.digest, &digest)) {
                entry.last_used = self.nextTick();
                return .{ .slot = slot, .width = entry.width, .height = entry.height };
            }
        }
        return null;
    }

    pub fn victim(self: *const Index, requested_budget: usize) usize {
        if (self.count() < boundedBudget(requested_budget)) {
            for (self.entries, 0..) |entry, slot| if (!entry.valid) return slot;
        }
        return self.oldestSlot();
    }

    pub fn trimTo(self: *Index, requested_budget: usize) TrimResult {
        const budget = boundedBudget(requested_budget);
        var result: TrimResult = .{};
        while (self.count() > budget) {
            const slot = self.oldestSlot();
            result.slots[result.count] = slot;
            result.count += 1;
            self.entries[slot] = .{};
        }
        return result;
    }

    pub fn commit(self: *Index, slot: usize, digest: Digest, width: u32, height: u32) void {
        std.debug.assert(slot < self.entries.len);
        std.debug.assert(width > 0 and height > 0);
        self.entries[slot] = .{
            .valid = true,
            .digest = digest,
            .width = width,
            .height = height,
            .last_used = self.nextTick(),
        };
    }

    pub fn count(self: *const Index) usize {
        var result: usize = 0;
        for (self.entries) |entry| {
            if (entry.valid) result += 1;
        }
        return result;
    }

    fn nextTick(self: *Index) u64 {
        self.tick +%= 1;
        if (self.tick == 0) {
            // More than 2^64 cache operations are not realistic, but keeping
            // zero reserved prevents an overflow from looking older than all
            // existing entries.
            self.tick = 1;
            for (&self.entries) |*entry| {
                if (entry.valid) entry.last_used = 1;
            }
        }
        return self.tick;
    }

    fn oldestSlot(self: *const Index) usize {
        var oldest_slot: ?usize = null;
        var oldest_tick: u64 = 0;
        for (self.entries, 0..) |entry, slot| {
            if (!entry.valid) continue;
            if (oldest_slot == null or entry.last_used < oldest_tick) {
                oldest_slot = slot;
                oldest_tick = entry.last_used;
            }
        }
        return oldest_slot orelse unreachable;
    }
};

test "cache index hits content and evicts the least recently used slot" {
    var index: Index = .{};
    var digests: [capacity + 1]Digest = undefined;
    for (&digests, 0..) |*digest, value| digest.* = contentDigest(&.{@intCast(value)});

    for (digests[0..capacity], 0..) |digest, slot| {
        try std.testing.expectEqual(slot, index.victim(capacity));
        index.commit(slot, digest, @intCast(100 + slot), 64);
    }
    try std.testing.expectEqual(capacity, index.count());
    const hit = index.lookup(digests[0]).?;
    try std.testing.expectEqual(@as(usize, 0), hit.slot);
    try std.testing.expectEqual(@as(u32, 100), hit.width);
    try std.testing.expectEqual(@as(usize, 1), index.victim(capacity));

    index.commit(index.victim(capacity), digests[capacity], 200, 80);
    try std.testing.expect(index.lookup(digests[1]) == null);
    try std.testing.expect(index.lookup(digests[0]) != null);
}

test "cache budget trims the least recently used entries and expands without reset" {
    var index: Index = .{};
    var digests: [capacity]Digest = undefined;
    for (&digests, 0..) |*digest, value| digest.* = contentDigest(&.{@intCast(value)});
    for (digests, 0..) |digest, slot| index.commit(slot, digest, @intCast(100 + slot), 64);

    _ = index.lookup(digests[0]);
    _ = index.lookup(digests[2]);
    const trimmed = index.trimTo(2);
    try std.testing.expectEqualSlices(usize, &.{ 1, 3 }, trimmed.items());
    try std.testing.expectEqual(@as(usize, 2), index.count());
    try std.testing.expect(index.lookup(digests[0]) != null);
    try std.testing.expect(index.lookup(digests[2]) != null);
    try std.testing.expect(index.lookup(digests[1]) == null);
    try std.testing.expectEqual(@as(usize, 1), index.victim(3));
    try std.testing.expectEqual(@as(usize, 1), boundedBudget(0));
    try std.testing.expectEqual(capacity, boundedBudget(capacity + 1));
}

test "content digest is stable and distinguishes encoded bytes" {
    const first = contentDigest("png-data");
    const duplicate = contentDigest("png-data");
    const different = contentDigest("jpeg-data");
    try std.testing.expectEqual(first, duplicate);
    try std.testing.expect(!std.mem.eql(u8, &first, &different));
}
