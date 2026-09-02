const std = @import("std");

pub const default_max_dimension: i32 = 4096;
pub const default_max_decoded_bytes: usize = 64 * 1024 * 1024;

const NativeImage = extern struct {
    pixels: ?[*]u8 = null,
    width: c_int = 0,
    height: c_int = 0,
    byte_count: usize = 0,
};

const NativeResult = enum(c_int) {
    ok = 0,
    invalid_argument = 1,
    invalid_data = 2,
    limit_exceeded = 3,
    decode_failed = 4,
    _,
};

extern fn zapp_image_decode_rgba(
    encoded: [*]const u8,
    encoded_length: usize,
    max_dimension: c_int,
    max_decoded_bytes: usize,
    out_image: *NativeImage,
) c_int;
extern fn zapp_image_free(pixels: ?[*]u8) void;

pub const Error = error{
    InvalidArgument,
    InvalidData,
    LimitExceeded,
    DecodeFailed,
};

pub const DecodedImage = struct {
    pixels: [*]u8,
    width: u32,
    height: u32,
    byte_count: usize,

    pub fn bytes(self: DecodedImage) []u8 {
        return self.pixels[0..self.byte_count];
    }

    pub fn deinit(self: *DecodedImage) void {
        zapp_image_free(self.pixels);
        self.* = undefined;
    }
};

pub fn decode(encoded: []const u8) Error!DecodedImage {
    return decodeWithLimits(encoded, default_max_dimension, default_max_decoded_bytes);
}

pub fn decodeWithLimits(encoded: []const u8, max_dimension: i32, max_decoded_bytes: usize) Error!DecodedImage {
    if (encoded.len == 0) return error.InvalidArgument;
    var native: NativeImage = .{};
    const result: NativeResult = @enumFromInt(zapp_image_decode_rgba(
        encoded.ptr,
        encoded.len,
        max_dimension,
        max_decoded_bytes,
        &native,
    ));
    if (result != .ok) return switch (result) {
        .invalid_argument => error.InvalidArgument,
        .invalid_data => error.InvalidData,
        .limit_exceeded => error.LimitExceeded,
        else => error.DecodeFailed,
    };
    const pixels = native.pixels orelse return error.DecodeFailed;
    if (native.width <= 0 or native.height <= 0 or native.byte_count == 0) {
        zapp_image_free(pixels);
        return error.DecodeFailed;
    }
    return .{
        .pixels = pixels,
        .width = @intCast(native.width),
        .height = @intCast(native.height),
        .byte_count = native.byte_count,
    };
}

test "embedded PNG decodes to bounded RGBA" {
    const encoded = @embedFile("../../assets/images/app-hero.png");
    var decoded = try decode(encoded);
    defer decoded.deinit();

    try std.testing.expectEqual(@as(u32, 128), decoded.width);
    try std.testing.expectEqual(@as(u32, 64), decoded.height);
    try std.testing.expectEqual(@as(usize, 128 * 64 * 4), decoded.byte_count);
    try std.testing.expectEqual(@as(u8, 255), decoded.bytes()[3]);
}

test "embedded JPEG decodes to bounded RGBA" {
    const encoded = @embedFile("../../assets/images/activity-card.jpg");
    var decoded = try decode(encoded);
    defer decoded.deinit();

    try std.testing.expectEqual(@as(u32, 96), decoded.width);
    try std.testing.expectEqual(@as(u32, 64), decoded.height);
    try std.testing.expectEqual(@as(usize, 96 * 64 * 4), decoded.byte_count);
    try std.testing.expectEqual(@as(u8, 255), decoded.bytes()[3]);
}

test "decoder rejects invalid data and configured limits" {
    try std.testing.expectError(error.InvalidData, decode("not an image"));
    const encoded = @embedFile("../../assets/images/app-hero.png");
    try std.testing.expectError(error.LimitExceeded, decodeWithLimits(encoded, 64, default_max_decoded_bytes));
    try std.testing.expectError(error.LimitExceeded, decodeWithLimits(encoded, default_max_dimension, 1024));
}
