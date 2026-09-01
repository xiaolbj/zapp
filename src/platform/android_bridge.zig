const std = @import("std");
const builtin = @import("builtin");

pub const max_text_bytes = 256;

pub const EventKind = enum(c_int) {
    composition_changed = 1,
    composition_committed = 2,
    composition_cancelled = 3,
    backspace = 4,
    submit = 5,
};

pub const Event = extern struct {
    kind_value: c_int,
    count: u32,
    text_length: usize,
    text_buffer: [max_text_bytes]u8,

    pub fn kind(self: *const Event) ?EventKind {
        return switch (self.kind_value) {
            @intFromEnum(EventKind.composition_changed) => .composition_changed,
            @intFromEnum(EventKind.composition_committed) => .composition_committed,
            @intFromEnum(EventKind.composition_cancelled) => .composition_cancelled,
            @intFromEnum(EventKind.backspace) => .backspace,
            @intFromEnum(EventKind.submit) => .submit,
            else => null,
        };
    }

    pub fn text(self: *const Event) []const u8 {
        return self.text_buffer[0..@min(self.text_length, self.text_buffer.len)];
    }
};

extern fn zapp_android_bridge_attach(activity: ?*const anyopaque) void;
extern fn zapp_android_bridge_set_ime_visible(visible: bool) void;
extern fn zapp_android_bridge_poll(event: *Event) bool;
extern fn zapp_android_bridge_reset() void;

pub fn attach(activity: ?*const anyopaque) void {
    if (comptime builtin.abi.isAndroid()) {
        zapp_android_bridge_attach(activity);
    }
}

pub fn setImeVisible(visible: bool) void {
    if (comptime builtin.abi.isAndroid()) {
        zapp_android_bridge_set_ime_visible(visible);
    }
}

pub fn poll(event: *Event) bool {
    if (comptime builtin.abi.isAndroid()) {
        return zapp_android_bridge_poll(event);
    }
    return false;
}

pub fn reset() void {
    if (comptime builtin.abi.isAndroid()) zapp_android_bridge_reset();
}

test "native event exposes bounded payload and rejects unknown kinds" {
    var event: Event = .{
        .kind_value = @intFromEnum(EventKind.composition_committed),
        .count = 0,
        .text_length = 3,
        .text_buffer = @splat(0),
    };
    @memcpy(event.text_buffer[0..3], "abc");
    try std.testing.expectEqual(EventKind.composition_committed, event.kind().?);
    try std.testing.expectEqualStrings("abc", event.text());

    event.kind_value = 99;
    try std.testing.expect(event.kind() == null);
    event.text_length = max_text_bytes + 100;
    try std.testing.expectEqual(max_text_bytes, event.text().len);
}
