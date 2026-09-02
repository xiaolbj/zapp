const std = @import("std");

pub const RequestId = u64;
pub const max_file_uri_bytes = 1024;
pub const max_file_preview_bytes = 4096;
pub const max_file_display_name_bytes = 256;
pub const max_file_mime_type_bytes = 128;
pub const file_stream_chunk_bytes = 4096;
pub const max_crash_report_export_bytes = 1024;

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

pub const FileStreamRequest = struct {
    request_id: RequestId,
    uri_length: usize,
    uri_buffer: [max_file_uri_bytes]u8,
    chunk_bytes: u32,

    pub fn init(request_id: RequestId, uri_text: []const u8, chunk_bytes: u32) ?FileStreamRequest {
        if (uri_text.len == 0 or uri_text.len > max_file_uri_bytes or chunk_bytes == 0) return null;
        var request: FileStreamRequest = .{
            .request_id = request_id,
            .uri_length = uri_text.len,
            .uri_buffer = @splat(0),
            .chunk_bytes = @min(chunk_bytes, file_stream_chunk_bytes),
        };
        @memcpy(request.uri_buffer[0..uri_text.len], uri_text);
        return request;
    }

    pub fn uri(self: *const FileStreamRequest) []const u8 {
        return self.uri_buffer[0..self.uri_length];
    }
};

pub const FileStreamChunk = struct {
    request_id: RequestId,
    offset: u64,
    data: []const u8,
};

pub const FileStreamTerminal = struct {
    request_id: RequestId,
    total_bytes: u64,
};

pub const CrashArchitecture = enum(u32) {
    unknown = 0,
    arm64 = 1,
    x86_64 = 2,
};

pub const NativeCrashReport = struct {
    signal_number: i32,
    signal_code: i32,
    architecture: CrashArchitecture,
    pc_in_app: bool,
    relative_pc: u64,
    absolute_pc: u64,
    fault_address: u64,
    process_id: i32,
    thread_id: i32,
    timestamp_seconds: i64,
    build_id_length: u8 = 0,
    build_id: [20]u8 = @splat(0),

    pub fn buildId(self: *const NativeCrashReport) []const u8 {
        return self.build_id[0..@min(@as(usize, self.build_id_length), self.build_id.len)];
    }
};

pub const CrashReportExportRequest = struct {
    request_id: RequestId,
    text_length: usize,
    text_buffer: [max_crash_report_export_bytes]u8,

    pub fn init(request_id: RequestId, report: NativeCrashReport) ?CrashReportExportRequest {
        var request: CrashReportExportRequest = .{
            .request_id = request_id,
            .text_length = 0,
            .text_buffer = @splat(0),
        };
        var build_id_hex: [40]u8 = undefined;
        const build_id = report.buildId();
        const build_id_text = if (build_id.len == 0) "unknown" else blk: {
            const digits = "0123456789abcdef";
            for (build_id, 0..) |byte, index| {
                build_id_hex[index * 2] = digits[byte >> 4];
                build_id_hex[index * 2 + 1] = digits[byte & 0x0f];
            }
            break :blk build_id_hex[0 .. build_id.len * 2];
        };
        const formatted = std.fmt.bufPrint(
            &request.text_buffer,
            "zapp native crash report v1\n" ++
                "signal={s} ({d})\n" ++
                "signal_code={d}\n" ++
                "architecture={s}\n" ++
                "build_id={s}\n" ++
                "pc_in_app={}\n" ++
                "relative_pc=0x{x}\n" ++
                "absolute_pc=0x{x}\n" ++
                "fault_address=0x{x}\n" ++
                "process_id={d}\n" ++
                "thread_id={d}\n" ++
                "timestamp_unix={d}\n",
            .{
                crashSignalName(report.signal_number),
                report.signal_number,
                report.signal_code,
                crashArchitectureName(report.architecture),
                build_id_text,
                report.pc_in_app,
                report.relative_pc,
                report.absolute_pc,
                report.fault_address,
                report.process_id,
                report.thread_id,
                report.timestamp_seconds,
            },
        ) catch return null;
        request.text_length = formatted.len;
        return request;
    }

    pub fn text(self: *const CrashReportExportRequest) []const u8 {
        return self.text_buffer[0..self.text_length];
    }
};

pub const CrashReportExportResult = struct {
    request_id: RequestId,
    chooser_opened: bool,
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
    stream_file: FileStreamRequest,
    cancel_file_stream: RequestId,
    share_crash_report: CrashReportExportRequest,
};

/// Logical navigation produced by a gamepad, TV remote, keyboard adapter, or
/// assistive input device. Native adapters translate platform-specific codes
/// before they enter the application state.
pub const NavigationCommand = enum(c_int) {
    next = 0,
    previous = 1,
    activate = 2,
    decrement = 3,
    increment = 4,
    back = 5,
    up = 6,
    down = 7,
    left = 8,
    right = 9,
    first = 10,
    last = 11,
};

pub const PlatformEvent = union(enum) {
    permission_result: PermissionResult,
    file_selected: FileSelection,
    file_selection_cancelled: RequestId,
    file_read_completed: FileReadResult,
    file_read_failed: FileReadFailure,
    file_stream_chunk: FileStreamChunk,
    file_stream_completed: FileStreamTerminal,
    file_stream_failed: FileReadFailure,
    file_stream_cancelled: FileStreamTerminal,
    ime_composition_changed: []const u8,
    ime_composition_committed: []const u8,
    ime_composition_cancelled,
    ime_backspace_requested: u32,
    ime_submit_requested,
    navigation_requested: NavigationCommand,
    memory_pressure: u32,
    native_crash_recovered: NativeCrashReport,
    crash_report_export_result: CrashReportExportResult,
};

fn crashSignalName(signal_number: i32) []const u8 {
    return switch (signal_number) {
        4 => "SIGILL",
        5 => "SIGTRAP",
        6 => "SIGABRT",
        7 => "SIGBUS",
        8 => "SIGFPE",
        11 => "SIGSEGV",
        31 => "SIGSYS",
        else => "SIGNAL",
    };
}

fn crashArchitectureName(architecture: CrashArchitecture) []const u8 {
    return switch (architecture) {
        .arm64 => "arm64-v8a",
        .x86_64 => "x86_64",
        .unknown => "unknown",
    };
}

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
    var source = [_]u8{ 'c', 'o', 'n', 't', 'e', 'n', 't', ':', '/', '/', 'x' };
    const request = FileReadRequest.init(9, &source, max_file_preview_bytes + 100).?;
    source[0] = 'X';
    try std.testing.expectEqualStrings("content://x", request.uri());
    try std.testing.expectEqual(@as(u32, max_file_preview_bytes), request.max_bytes);
    try std.testing.expect(FileReadRequest.init(1, "", 1) == null);
}

test "file stream requests own URI bytes and clamp chunk size" {
    var source = [_]u8{ 'c', 'o', 'n', 't', 'e', 'n', 't', ':', '/', '/', 'x' };
    const request = FileStreamRequest.init(10, &source, file_stream_chunk_bytes + 100).?;
    source[0] = 'X';
    try std.testing.expectEqualStrings("content://x", request.uri());
    try std.testing.expectEqual(@as(u32, file_stream_chunk_bytes), request.chunk_bytes);
    try std.testing.expect(FileStreamRequest.init(1, "", 1) == null);
}

test "crash export request owns stable diagnostic text" {
    var report: NativeCrashReport = .{
        .signal_number = 11,
        .signal_code = 1,
        .architecture = .arm64,
        .pc_in_app = true,
        .relative_pc = 0x1234,
        .absolute_pc = 0x70001234,
        .fault_address = 0,
        .process_id = 100,
        .thread_id = 101,
        .timestamp_seconds = 1_700_000_000,
    };
    report.build_id_length = 3;
    report.build_id[0..3].* = .{ 0xab, 0xcd, 0x01 };

    const request = CrashReportExportRequest.init(27, report).?;
    try std.testing.expectEqual(@as(RequestId, 27), request.request_id);
    try std.testing.expect(std.mem.indexOf(u8, request.text(), "signal=SIGSEGV (11)\n") != null);
    try std.testing.expect(std.mem.indexOf(u8, request.text(), "architecture=arm64-v8a\n") != null);
    try std.testing.expect(std.mem.indexOf(u8, request.text(), "build_id=abcd01\n") != null);
    try std.testing.expect(std.mem.indexOf(u8, request.text(), "relative_pc=0x1234\n") != null);
    report.build_id[0] = 0;
    try std.testing.expect(std.mem.indexOf(u8, request.text(), "build_id=abcd01\n") != null);
}
