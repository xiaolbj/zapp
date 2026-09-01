const std = @import("std");
const builtin = @import("builtin");
const clay = @import("zclay");

const embedded_font: []const u8 = if (builtin.is_test)
    ""
else
    @embedFile("../../assets/fonts/NotoSansSC-wght.ttf");

var ready = false;

extern fn zapp_font_setup(data: [*]const u8, data_len: c_int) bool;
extern fn zapp_font_shutdown() void;
extern fn zapp_font_measure(
    text: [*]const u8,
    text_len: c_int,
    size: f32,
    spacing: f32,
    height: *f32,
) f32;
extern fn zapp_font_draw(
    text: [*]const u8,
    text_len: c_int,
    x: f32,
    y: f32,
    size: f32,
    spacing: f32,
    r: u8,
    g: u8,
    b: u8,
    a: u8,
) void;
extern fn zapp_font_flush() void;

pub fn setup() bool {
    if (ready) return true;
    if (embedded_font.len == 0 or embedded_font.len > std.math.maxInt(c_int)) return false;
    ready = zapp_font_setup(embedded_font.ptr, @intCast(embedded_font.len));
    return ready;
}

pub fn shutdown() void {
    if (!ready) return;
    zapp_font_shutdown();
    ready = false;
}

pub fn measure(text: []const u8, config: *clay.TextElementConfig, _: void) clay.Dimensions {
    if (!ready or text.len > std.math.maxInt(c_int)) return fallbackMeasure(text, config);

    var measured_height: f32 = 0;
    const width = zapp_font_measure(
        text.ptr,
        @intCast(text.len),
        @floatFromInt(config.font_size),
        @floatFromInt(config.letter_spacing),
        &measured_height,
    );
    return .{
        .w = width,
        .h = if (config.line_height > 0) @floatFromInt(config.line_height) else measured_height,
    };
}

pub fn draw(bounds: clay.BoundingBox, data: clay.TextRenderData) void {
    if (!ready) return;
    const text = data.string_contents.chars[0..@intCast(data.string_contents.length)];
    if (text.len == 0 or text.len > std.math.maxInt(c_int)) return;
    zapp_font_draw(
        text.ptr,
        @intCast(text.len),
        bounds.x,
        bounds.y,
        @floatFromInt(data.font_size),
        @floatFromInt(data.letter_spacing),
        colorByte(data.text_color[0]),
        colorByte(data.text_color[1]),
        colorByte(data.text_color[2]),
        colorByte(data.text_color[3]),
    );
}

pub fn flush() void {
    if (ready) zapp_font_flush();
}

fn fallbackMeasure(text: []const u8, config: *clay.TextElementConfig) clay.Dimensions {
    const glyph_count: f32 = @floatFromInt(utf8CodepointCount(text));
    const font_size: f32 = @floatFromInt(config.font_size);
    return .{
        .w = glyph_count * (font_size * 0.625 + @as(f32, @floatFromInt(config.letter_spacing))),
        .h = if (config.line_height > 0) @floatFromInt(config.line_height) else font_size,
    };
}

fn utf8CodepointCount(text: []const u8) usize {
    var count: usize = 0;
    for (text) |byte| {
        if (byte & 0xC0 != 0x80) count += 1;
    }
    return count;
}

fn colorByte(value: f32) u8 {
    return @intFromFloat(std.math.clamp(value, 0, 255));
}

test "fallback metrics count UTF-8 codepoints" {
    var config: clay.TextElementConfig = .{ .font_size = 16 };
    const result = measure("A中", &config, {});
    try std.testing.expectEqual(@as(f32, 20), result.w);
    try std.testing.expectEqual(@as(f32, 16), result.h);
}
