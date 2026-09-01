const std = @import("std");
const builtin = @import("builtin");

pub const max_payload_bytes = 1024;

pub const EventKind = enum(c_int) {
    composition_changed = 1,
    composition_committed = 2,
    composition_cancelled = 3,
    backspace = 4,
    submit = 5,
    permission_result = 6,
    file_selected = 7,
    file_selection_cancelled = 8,
};

pub const Event = extern struct {
    kind_value: c_int,
    permission_value: c_int,
    request_id: u64,
    count: u32,
    granted: bool,
    reserved: [3]u8,
    text_length: usize,
    text_buffer: [max_payload_bytes]u8,

    pub fn kind(self: *const Event) ?EventKind {
        return switch (self.kind_value) {
            @intFromEnum(EventKind.composition_changed) => .composition_changed,
            @intFromEnum(EventKind.composition_committed) => .composition_committed,
            @intFromEnum(EventKind.composition_cancelled) => .composition_cancelled,
            @intFromEnum(EventKind.backspace) => .backspace,
            @intFromEnum(EventKind.submit) => .submit,
            @intFromEnum(EventKind.permission_result) => .permission_result,
            @intFromEnum(EventKind.file_selected) => .file_selected,
            @intFromEnum(EventKind.file_selection_cancelled) => .file_selection_cancelled,
            else => null,
        };
    }

    pub fn text(self: *const Event) []const u8 {
        return self.text_buffer[0..@min(self.text_length, self.text_buffer.len)];
    }
};

extern fn zapp_android_bridge_attach(activity: ?*const anyopaque) void;
extern fn zapp_android_bridge_set_ime_visible(visible: bool) void;
extern fn zapp_android_bridge_request_permission(request_id: u64, permission: c_int) bool;
extern fn zapp_android_bridge_open_file(request_id: u64) bool;
extern fn zapp_android_bridge_poll(event: *Event) bool;
extern fn zapp_android_bridge_reset() void;

pub fn attach(activity: ?*const anyopaque) void {
    if (comptime builtin.abi.isAndroid()) zapp_android_bridge_attach(activity);
}

pub fn setImeVisible(visible: bool) void {
    if (comptime builtin.abi.isAndroid()) zapp_android_bridge_set_ime_visible(visible);
}

pub fn requestPermission(request_id: u64, permission: c_int) bool {
    if (comptime builtin.abi.isAndroid()) {
        return zapp_android_bridge_request_permission(request_id, permission);
    }
    return false;
}

pub fn openFile(request_id: u64) bool {
    if (comptime builtin.abi.isAndroid()) return zapp_android_bridge_open_file(request_id);
    return false;
}

pub fn poll(event: *Event) bool {
    if (comptime builtin.abi.isAndroid()) return zapp_android_bridge_poll(event);
    return false;
}

pub fn reset() void {
    if (comptime builtin.abi.isAndroid()) zapp_android_bridge_reset();
}

test "native event exposes request metadata and bounded payload" {
    var event: Event = .{
        .kind_value = @intFromEnum(EventKind.file_selected),
        .permission_value = 0,
        .request_id = 42,
        .count = 0,
        .granted = false,
        .reserved = @splat(0),
        .text_length = 3,
        .text_buffer = @splat(0),
    };
    @memcpy(event.text_buffer[0..3], "abc");
    try std.testing.expectEqual(EventKind.file_selected, event.kind().?);
    try std.testing.expectEqual(@as(u64, 42), event.request_id);
    try std.testing.expectEqualStrings("abc", event.text());

    event.kind_value = 99;
    try std.testing.expect(event.kind() == null);
    event.text_length = max_payload_bytes + 100;
    try std.testing.expectEqual(max_payload_bytes, event.text().len);
}
