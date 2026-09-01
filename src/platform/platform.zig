pub const RequestId = u64;
pub const max_file_uri_bytes = 1024;
pub const max_file_preview_bytes = 4096;
pub const max_file_display_name_bytes = 256;
pub const max_file_mime_type_bytes = 128;

pub const android = @import("android_bridge.zig");

comptime {
    if (max_file_preview_bytes != android.max_payload_bytes or
        max_file_display_name_bytes != android.max_file_display_name_bytes or
        max_file_mime_type_bytes != android.max_file_mime_type_bytes)
    {
        @compileError("platform and Android file payload capacities must match");
    }
}

pub const Permission = enum(c_int) {
    camera,
    microphone,
    notifications,
    media,
};

pub const PermissionResult = struct {
    request_id: RequestId,
    permission: Permission,
    granted: bool,
};

pub const FileSelection = struct {
    request_id: RequestId,
    uri: []const u8,
};

pub const FileReadError = enum(c_int) {
    invalid_uri = 1,
    not_found = 2,
    permission_denied = 3,
    io = 4,
    unsupported = 5,
};

pub const FileReadRequest = struct {
    request_id: RequestId,
    uri_length: usize,
    uri_buffer: [max_file_uri_bytes]u8,
    max_bytes: u32,

    pub fn init(request_id: RequestId, uri_text: []const u8, max_bytes: u32) ?FileReadRequest {
        if (uri_text.len == 0 or uri_text.len > max_file_uri_bytes or max_bytes == 0) return null;
        var request: FileReadRequest = .{
            .request_id = request_id,
            .uri_length = uri_text.len,
            .uri_buffer = @splat(0),
            .max_bytes = @min(max_bytes, max_file_preview_bytes),
        };
        @memcpy(request.uri_buffer[0..uri_text.len], uri_text);
        return request;
    }

    pub fn uri(self: *const FileReadRequest) []const u8 {
        return self.uri_buffer[0..self.uri_length];
    }
};

pub const FileReadResult = struct {
    request_id: RequestId,
    data: []const u8,
    truncated: bool,
    display_name: []const u8 = "",
    mime_type: []const u8 = "",
    size: ?u64 = null,
};

pub const FileReadFailure = struct {
    request_id: RequestId,
    error_kind: FileReadError,
};

pub const PlatformRequest = union(enum) {
    request_permission: struct {
        request_id: RequestId,
        permission: Permission,
    },
    open_file: struct {
        request_id: RequestId,
    },
    read_file: FileReadRequest,
};

/// Logical navigation produced by a gamepad, TV remote, keyboard adapter, or
/// assistive input device. Native adapters translate platform-specific codes
/// before they enter the application state.
pub const NavigationCommand = enum {
    next,
    previous,
    activate,
    decrement,
    increment,
    back,
};

pub const PlatformEvent = union(enum) {
    permission_result: PermissionResult,
    file_selected: FileSelection,
    file_selection_cancelled: RequestId,
    file_read_completed: FileReadResult,
    file_read_failed: FileReadFailure,
    ime_composition_changed: []const u8,
    ime_composition_committed: []const u8,
    ime_composition_cancelled,
    ime_backspace_requested: u32,
    ime_submit_requested,
    navigation_requested: NavigationCommand,
};

/// Platform implementations enqueue results and the app consumes them on its
/// update thread. No platform call is allowed to synchronously block rendering.
pub const EventSink = struct {
    context: ?*anyopaque,
    push_fn: *const fn (?*anyopaque, PlatformEvent) void,

    pub fn push(self: EventSink, event: PlatformEvent) void {
        self.push_fn(self.context, event);
    }
};

test "file read requests own URI bytes and clamp preview size" {
    const std = @import("std");
    var source = [_]u8{ 'c', 'o', 'n', 't', 'e', 'n', 't', ':', '/', '/', 'x' };
    const request = FileReadRequest.init(9, &source, max_file_preview_bytes + 100).?;
    source[0] = 'X';
    try std.testing.expectEqualStrings("content://x", request.uri());
    try std.testing.expectEqual(@as(u32, max_file_preview_bytes), request.max_bytes);
    try std.testing.expect(FileReadRequest.init(1, "", 1) == null);
}
