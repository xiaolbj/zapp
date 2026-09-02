pub const Action = @import("action.zig").Action;
pub const Model = @import("model.zig").Model;
const reducer = @import("reducer.zig");
const platform = @import("../platform/platform.zig");
const PlatformEvent = platform.PlatformEvent;

const max_platform_requests = 8;

pub const App = struct {
    model: Model = .{},
    platform_requests: [max_platform_requests]platform.PlatformRequest = undefined,
    platform_request_count: usize = 0,
    next_request_id: platform.RequestId = 1,

    pub fn dispatch(self: *App, action: Action) void {
        reducer.update(&self.model, action);
        switch (action) {
            .platform_permission_requested => |permission| {
                const request_id = self.allocateRequestId();
                if (!self.enqueuePlatformRequest(.{ .request_permission = .{
                    .request_id = request_id,
                    .permission = permission,
                } })) {
                    reducer.update(&self.model, .{ .platform_permission_result = .{
                        .request_id = request_id,
                        .permission = permission,
                        .granted = false,
                    } });
                }
            },
            .platform_file_picker_requested => {
                const request_id = self.allocateRequestId();
                if (!self.enqueuePlatformRequest(.{ .open_file = .{ .request_id = request_id } })) {
                    reducer.update(&self.model, .{ .platform_file_selection_cancelled = request_id });
                }
            },
            .platform_file_selected => |selection| {
                const read_request = platform.FileReadRequest.init(
                    selection.request_id,
                    selection.uri,
                    platform.max_file_preview_bytes,
                );
                if (read_request == null or !self.enqueuePlatformRequest(.{ .read_file = read_request.? })) {
                    reducer.update(&self.model, .{ .platform_file_read_failed = .{
                        .request_id = selection.request_id,
                        .error_kind = if (read_request == null) .invalid_uri else .unsupported,
                    } });
                }
            },
            .platform_file_stream_requested => {
                const request_id = self.allocateRequestId();
                self.dispatch(.{ .platform_file_stream_started = request_id });
                const stream_request = platform.FileStreamRequest.init(
                    request_id,
                    self.model.selectedFileUri(),
                    platform.file_stream_chunk_bytes,
                );
                if (stream_request == null or !self.enqueuePlatformRequest(.{ .stream_file = stream_request.? })) {
                    self.dispatch(.{ .platform_file_stream_failed = .{
                        .request_id = request_id,
                        .error_kind = if (stream_request == null) .invalid_uri else .unsupported,
                    } });
                }
            },
            .platform_file_stream_cancel_requested => {
                const request_id = self.model.last_file_stream_request_id;
                if (request_id != 0 and self.model.file_stream_pending and
                    !self.enqueuePlatformRequest(.{ .cancel_file_stream = request_id }))
                {
                    self.dispatch(.{ .platform_file_stream_failed = .{
                        .request_id = request_id,
                        .error_kind = .unsupported,
                    } });
                }
            },
            .platform_crash_report_export_requested => {
                const report = self.model.last_native_crash orelse return;
                const request_id = self.allocateRequestId();
                self.dispatch(.{ .platform_crash_report_export_started = request_id });
                const export_request = platform.CrashReportExportRequest.init(request_id, report);
                if (export_request == null or
                    !self.enqueuePlatformRequest(.{ .share_crash_report = export_request.? }))
                {
                    self.dispatch(.{ .platform_crash_report_export_result = .{
                        .request_id = request_id,
                        .chooser_opened = false,
                    } });
                }
            },
            else => {},
        }
    }

    pub fn takePlatformRequest(self: *App) ?platform.PlatformRequest {
        if (self.platform_request_count == 0) return null;
        const request = self.platform_requests[0];
        var index: usize = 1;
        while (index < self.platform_request_count) : (index += 1) {
            self.platform_requests[index - 1] = self.platform_requests[index];
        }
        self.platform_request_count -= 1;
        return request;
    }

    /// Platform event payloads are consumed synchronously on the update thread.
    pub fn dispatchPlatformEvent(self: *App, event: PlatformEvent) void {
        switch (event) {
            .permission_result => |result| self.dispatch(.{ .platform_permission_result = result }),
            .file_selected => |selection| self.dispatch(.{ .platform_file_selected = selection }),
            .file_selection_cancelled => |request_id| self.dispatch(.{
                .platform_file_selection_cancelled = request_id,
            }),
            .file_read_completed => |result| self.dispatch(.{ .platform_file_read_completed = result }),
            .file_read_failed => |failure| self.dispatch(.{ .platform_file_read_failed = failure }),
            .file_stream_chunk => |chunk| self.dispatch(.{ .platform_file_stream_chunk = chunk }),
            .file_stream_completed => |result| self.dispatch(.{ .platform_file_stream_completed = result }),
            .file_stream_failed => |failure| self.dispatch(.{ .platform_file_stream_failed = failure }),
            .file_stream_cancelled => |result| self.dispatch(.{ .platform_file_stream_cancelled = result }),
            .ime_composition_changed => |text| self.dispatch(.{ .text_composition_changed = text }),
            .ime_composition_committed => |text| self.dispatch(.{ .text_composition_committed = text }),
            .ime_composition_cancelled => self.dispatch(.text_composition_cancelled),
            .ime_backspace_requested => |count| {
                for (0..count) |_| self.dispatch(.text_backspace);
            },
            .ime_submit_requested => self.dispatch(.text_submitted),
            .navigation_requested => |command| switch (command) {
                .next => self.dispatch(.focus_next_requested),
                .previous => self.dispatch(.focus_previous_requested),
                .activate => self.dispatch(.focused_control_activate_requested),
                .decrement => self.dispatch(.focused_control_left_requested),
                .increment => self.dispatch(.focused_control_right_requested),
                .back => self.dispatch(.back_requested),
                .up => self.dispatch(.focused_control_up_requested),
                .down => self.dispatch(.focused_control_down_requested),
                .left => self.dispatch(.focused_control_left_requested),
                .right => self.dispatch(.focused_control_right_requested),
                .first => self.dispatch(.focused_control_home_requested),
                .last => self.dispatch(.focused_control_end_requested),
            },
            .native_crash_recovered => |report| self.dispatch(.{ .platform_native_crash_recovered = report }),
            .crash_report_export_result => |result| self.dispatch(.{
                .platform_crash_report_export_result = result,
            }),
        }
    }

    fn allocateRequestId(self: *App) platform.RequestId {
        const request_id = self.next_request_id;
        self.next_request_id +%= 1;
        if (self.next_request_id == 0) self.next_request_id = 1;
        return request_id;
    }

    fn enqueuePlatformRequest(self: *App, request: platform.PlatformRequest) bool {
        if (self.platform_request_count == self.platform_requests.len) return false;
        self.platform_requests[self.platform_request_count] = request;
        self.platform_request_count += 1;
        return true;
    }
};

test "IME platform events enter the reducer synchronously" {
    const std = @import("std");
    var app: App = .{};
    app.dispatchPlatformEvent(.{ .ime_composition_changed = "ni" });
    try std.testing.expectEqualStrings("ni", app.model.textComposition());
    app.dispatchPlatformEvent(.{ .ime_composition_committed = "你" });
    try std.testing.expectEqualStrings("你", app.model.text());
}

test "platform navigation commands share frame-latched focus actions" {
    const std = @import("std");
    var app: App = .{};
    app.dispatchPlatformEvent(.{ .navigation_requested = .next });
    app.dispatchPlatformEvent(.{ .navigation_requested = .activate });
    app.dispatchPlatformEvent(.{ .navigation_requested = .increment });
    app.dispatchPlatformEvent(.{ .navigation_requested = .up });
    app.dispatchPlatformEvent(.{ .navigation_requested = .left });
    app.dispatchPlatformEvent(.{ .navigation_requested = .first });
    app.dispatchPlatformEvent(.{ .navigation_requested = .last });
    app.dispatchPlatformEvent(.{ .navigation_requested = .back });

    try std.testing.expect(app.model.focus_next_requested);
    try std.testing.expect(app.model.focused_control_activate_requested);
    try std.testing.expect(app.model.focused_control_right_requested);
    try std.testing.expect(app.model.focused_control_up_requested);
    try std.testing.expect(app.model.focused_control_left_requested);
    try std.testing.expect(app.model.focused_control_home_requested);
    try std.testing.expect(app.model.focused_control_end_requested);
    try std.testing.expect(app.model.back_requested);

    app.dispatch(.input_consumed);
    try std.testing.expect(!app.model.focus_next_requested);
    try std.testing.expect(!app.model.focused_control_activate_requested);
    try std.testing.expect(!app.model.focused_control_right_requested);
    try std.testing.expect(!app.model.focused_control_home_requested);
    try std.testing.expect(!app.model.focused_control_end_requested);
    try std.testing.expect(!app.model.back_requested);
}

test "IME editing commands use the same reducer actions as desktop input" {
    const std = @import("std");
    var app: App = .{};
    app.dispatchPlatformEvent(.{ .ime_composition_committed = "abc" });
    app.dispatchPlatformEvent(.{ .ime_backspace_requested = 2 });
    try std.testing.expectEqualStrings("a", app.model.text());

    app.dispatchPlatformEvent(.ime_submit_requested);
    try std.testing.expectEqual(@as(u32, 1), app.model.application_name_input.submission_count);
}

test "platform actions enqueue stable request identifiers and consume results" {
    const std = @import("std");
    var app: App = .{};
    app.dispatch(.{ .platform_permission_requested = .camera });
    app.dispatch(.platform_file_picker_requested);

    const permission_request = app.takePlatformRequest().?.request_permission;
    const file_request = app.takePlatformRequest().?.open_file;
    try std.testing.expectEqual(@as(platform.RequestId, 1), permission_request.request_id);
    try std.testing.expectEqual(platform.Permission.camera, permission_request.permission);
    try std.testing.expectEqual(@as(platform.RequestId, 2), file_request.request_id);
    try std.testing.expect(app.takePlatformRequest() == null);

    app.dispatchPlatformEvent(.{ .permission_result = .{
        .request_id = permission_request.request_id,
        .permission = permission_request.permission,
        .granted = true,
    } });
    app.dispatchPlatformEvent(.{ .file_selected = .{
        .request_id = file_request.request_id,
        .uri = "content://zapp/example",
    } });
    const read_request = app.takePlatformRequest().?.read_file;
    try std.testing.expectEqual(file_request.request_id, read_request.request_id);
    try std.testing.expectEqualStrings("content://zapp/example", read_request.uri());
    try std.testing.expect(app.model.file_read_pending);

    app.dispatchPlatformEvent(.{ .file_read_completed = .{
        .request_id = read_request.request_id,
        .data = "hello",
        .truncated = false,
        .display_name = "example.txt",
        .mime_type = "text/plain",
        .size = 5,
    } });
    try std.testing.expect(app.model.last_permission_granted);
    try std.testing.expectEqualStrings("content://zapp/example", app.model.selectedFileUri());
    try std.testing.expectEqualStrings("hello", app.model.filePreview());
    try std.testing.expectEqualStrings("example.txt", app.model.fileDisplayName());
    try std.testing.expectEqualStrings("text/plain", app.model.fileMimeType());
    try std.testing.expectEqual(@as(u64, 5), app.model.file_size);
}

test "file stream requests and cancellation use stable identifiers" {
    const std = @import("std");
    var app: App = .{};
    app.dispatchPlatformEvent(.{ .file_selected = .{
        .request_id = 7,
        .uri = "content://zapp/large.bin",
    } });
    _ = app.takePlatformRequest().?.read_file;
    app.dispatchPlatformEvent(.{ .file_read_completed = .{
        .request_id = 7,
        .data = "preview",
        .truncated = true,
        .size = 8192,
    } });

    app.dispatch(.platform_file_stream_requested);
    const stream_request = app.takePlatformRequest().?.stream_file;
    try std.testing.expectEqual(app.model.last_file_stream_request_id, stream_request.request_id);
    try std.testing.expectEqualStrings("content://zapp/large.bin", stream_request.uri());
    try std.testing.expect(app.model.file_stream_pending);

    app.dispatch(.platform_file_stream_cancel_requested);
    const cancel_request = app.takePlatformRequest().?.cancel_file_stream;
    try std.testing.expectEqual(stream_request.request_id, cancel_request);
    try std.testing.expect(app.model.file_stream_cancel_pending);
}

test "recovered native crash enters app model" {
    const std = @import("std");
    var app: App = .{};
    var report: platform.NativeCrashReport = .{
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
    report.build_id_length = 2;
    report.build_id[0..2].* = .{ 0xab, 0xcd };
    app.dispatchPlatformEvent(.{ .native_crash_recovered = report });

    try std.testing.expect(app.model.last_native_crash != null);
    try std.testing.expectEqual(report.signal_number, app.model.last_native_crash.?.signal_number);
    try std.testing.expectEqual(report.relative_pc, app.model.last_native_crash.?.relative_pc);
    try std.testing.expectEqual(report.architecture, app.model.last_native_crash.?.architecture);
    try std.testing.expectEqualSlices(u8, &.{ 0xab, 0xcd }, app.model.last_native_crash.?.buildId());
}

test "crash report export owns text and accepts only matching result" {
    const std = @import("std");
    var app: App = .{};
    var report: platform.NativeCrashReport = .{
        .signal_number = 11,
        .signal_code = 1,
        .architecture = .x86_64,
        .pc_in_app = true,
        .relative_pc = 0x2468,
        .absolute_pc = 0x70002468,
        .fault_address = 0,
        .process_id = 200,
        .thread_id = 201,
        .timestamp_seconds = 1_700_000_001,
    };
    report.build_id_length = 2;
    report.build_id[0..2].* = .{ 0x12, 0x34 };
    app.model.last_native_crash = report;

    app.dispatch(.platform_crash_report_export_requested);
    const request = app.takePlatformRequest().?.share_crash_report;
    try std.testing.expect(app.model.crash_report_export_pending);
    try std.testing.expectEqual(request.request_id, app.model.last_crash_report_export_request_id);
    try std.testing.expect(std.mem.indexOf(u8, request.text(), "build_id=1234\n") != null);

    app.dispatchPlatformEvent(.{ .crash_report_export_result = .{
        .request_id = request.request_id + 1,
        .chooser_opened = true,
    } });
    try std.testing.expect(app.model.crash_report_export_pending);

    app.dispatchPlatformEvent(.{ .crash_report_export_result = .{
        .request_id = request.request_id,
        .chooser_opened = true,
    } });
    try std.testing.expect(!app.model.crash_report_export_pending);
    try std.testing.expect(app.model.crash_report_export_attempted);
    try std.testing.expect(app.model.crash_report_export_chooser_opened);
}

test {
    _ = @import("reducer.zig");
}
