const std = @import("std");

pub const max_encoded_bytes: usize = 16 * 1024 * 1024;
const initial_capacity: usize = 64 * 1024;

pub const LoadFailure = enum(u8) {
    invalid_data,
    encoded_limit_exceeded,
    decoded_limit_exceeded,
    out_of_memory,
    gpu_upload_failed,
    interrupted,
    invalid_uri,
    not_found,
    permission_denied,
    io,
    unsupported,
};

pub const AccumulatorError = error{
    InvalidRequest,
    NonContiguous,
    LimitExceeded,
    OutOfMemory,
};

/// Owns encoded bytes while an asynchronous platform stream is in flight.
/// The buffer grows geometrically up to max_encoded_bytes and is released as
/// soon as the renderer has consumed the completed image.
pub const Accumulator = struct {
    request_id: u64 = 0,
    buffer: []u8 = &.{},
    length: usize = 0,
    active: bool = false,

    pub fn begin(
        self: *Accumulator,
        allocator: std.mem.Allocator,
        request_id: u64,
        expected_size: ?u64,
    ) AccumulatorError!void {
        self.reset(allocator);
        if (request_id == 0) return error.InvalidRequest;

        const capacity = if (expected_size) |size| blk: {
            if (size == 0 or size > max_encoded_bytes) return error.LimitExceeded;
            break :blk @as(usize, @intCast(size));
        } else initial_capacity;

        self.buffer = allocator.alloc(u8, capacity) catch return error.OutOfMemory;
        self.request_id = request_id;
        self.active = true;
    }

    pub fn append(
        self: *Accumulator,
        allocator: std.mem.Allocator,
        request_id: u64,
        offset: u64,
        bytes: []const u8,
    ) AccumulatorError!void {
        if (!self.active or request_id != self.request_id) return error.InvalidRequest;
        if (offset != self.length) return error.NonContiguous;
        if (bytes.len == 0) return;
        const required = std.math.add(usize, self.length, bytes.len) catch return error.LimitExceeded;
        if (required > max_encoded_bytes) return error.LimitExceeded;
        try self.ensureCapacity(allocator, required);
        @memcpy(self.buffer[self.length..required], bytes);
        self.length = required;
    }

    pub fn finish(self: *Accumulator, request_id: u64, total_bytes: u64) AccumulatorError![]const u8 {
        if (!self.active or request_id != self.request_id) return error.InvalidRequest;
        if (total_bytes != self.length or self.length == 0) return error.NonContiguous;
        return self.buffer[0..self.length];
    }

    pub fn reset(self: *Accumulator, allocator: std.mem.Allocator) void {
        if (self.buffer.len > 0) allocator.free(self.buffer);
        self.* = .{};
    }

    fn ensureCapacity(
        self: *Accumulator,
        allocator: std.mem.Allocator,
        required: usize,
    ) AccumulatorError!void {
        if (required <= self.buffer.len) return;
        var capacity = self.buffer.len;
        while (capacity < required) {
            capacity = @min(max_encoded_bytes, std.math.mul(usize, capacity, 2) catch max_encoded_bytes);
            if (capacity < required and capacity == max_encoded_bytes) return error.LimitExceeded;
        }
        const replacement = allocator.alloc(u8, capacity) catch return error.OutOfMemory;
        @memcpy(replacement[0..self.length], self.buffer[0..self.length]);
        allocator.free(self.buffer);
        self.buffer = replacement;
    }
};

test "runtime image accumulator accepts ordered bounded chunks" {
    var accumulator: Accumulator = .{};
    defer accumulator.reset(std.testing.allocator);
    try accumulator.begin(std.testing.allocator, 7, null);
    try accumulator.append(std.testing.allocator, 7, 0, "abc");
    try accumulator.append(std.testing.allocator, 7, 3, "def");
    try std.testing.expectEqualStrings("abcdef", try accumulator.finish(7, 6));
}

test "runtime image accumulator rejects stale gaps and oversized metadata" {
    var accumulator: Accumulator = .{};
    defer accumulator.reset(std.testing.allocator);
    try std.testing.expectError(
        error.LimitExceeded,
        accumulator.begin(std.testing.allocator, 1, max_encoded_bytes + 1),
    );
    try accumulator.begin(std.testing.allocator, 2, 8);
    try std.testing.expectError(
        error.NonContiguous,
        accumulator.append(std.testing.allocator, 2, 1, "x"),
    );
    try std.testing.expectError(error.InvalidRequest, accumulator.finish(3, 0));
}
