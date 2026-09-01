const std = @import("std");
const sokol = @import("sokol");
const zapp = @import("zapp");

const sapp = sokol.app;
const slog = sokol.log;
const stm = sokol.time;
const builtin = @import("builtin");

const App = zapp.app.App;
const ClayRenderer = zapp.render.ClayRenderer;
const max_platform_events_per_frame = 32;

const state = struct {
    var app: App = .{};
    var renderer: ClayRenderer = .{};
    var metrics: zapp.performance.Collector = .{};
};

export fn init() void {
    stm.setup();
    state.metrics.reset();
    if (comptime builtin.abi.isAndroid()) {
        zapp.platform.android.attach(sapp.androidGetNativeActivity());
    }
    state.app.dispatch(.{ .resized = .{
        .width = sapp.width(),
        .height = sapp.height(),
        .dpi_scale = sapp.dpiScale(),
    } });
    if (!state.renderer.setup() or !zapp.ui.setup(&state.app.model)) {
        sapp.requestQuit();
    }
}

export fn frame() void {
    const frame_start = stm.now();
    const keyboard_was_visible = state.app.model.text_field_focused;
    drainPlatformEvents();
    state.app.dispatch(.{ .tick = sapp.frameDuration() });
    const ui_start = stm.now();
    const ui_frame = zapp.ui.build(&state.app.model);
    const ui_cpu_ms: f32 = @floatCast(stm.ms(stm.since(ui_start)));
    if (comptime builtin.abi.isAndroid()) {
        zapp.platform.android.updateAccessibility(ui_frame.semantic_nodes);
    }
    for (ui_frame.actions) |action| state.app.dispatch(action);
    processPlatformRequests();
    if (keyboard_was_visible != state.app.model.text_field_focused) {
        setKeyboardVisible(state.app.model.text_field_focused);
    }
    state.app.dispatch(.input_consumed);
    const render_start = stm.now();
    state.renderer.draw(ui_frame);
    const render_cpu_ms: f32 = @floatCast(stm.ms(stm.since(render_start)));
    if (state.metrics.record(.{
        .frame_interval_ms = @floatCast(sapp.frameDuration() * 1000.0),
        .ui_cpu_ms = ui_cpu_ms,
        .render_cpu_ms = render_cpu_ms,
        .total_cpu_ms = @floatCast(stm.ms(stm.since(frame_start))),
        .command_count = @intCast(ui_frame.commands.len),
        .semantic_node_count = @intCast(ui_frame.semantic_nodes.len),
    })) |snapshot| state.app.dispatch(.{ .performance_updated = snapshot });
}

fn drainPlatformEvents() void {
    if (comptime !builtin.abi.isAndroid()) return;

    var native_event: zapp.platform.android.Event = undefined;
    var event_count: usize = 0;
    while (event_count < max_platform_events_per_frame) : (event_count += 1) {
        if (!zapp.platform.android.poll(&native_event)) break;
        const kind = native_event.kind() orelse continue;
        switch (kind) {
            .composition_changed => state.app.dispatchPlatformEvent(.{
                .ime_composition_changed = native_event.text(),
            }),
            .composition_committed => state.app.dispatchPlatformEvent(.{
                .ime_composition_committed = native_event.text(),
            }),
            .composition_cancelled => state.app.dispatchPlatformEvent(.ime_composition_cancelled),
            .backspace => state.app.dispatchPlatformEvent(.{
                .ime_backspace_requested = @min(native_event.count, 64),
            }),
            .submit => state.app.dispatchPlatformEvent(.ime_submit_requested),
            .permission_result => {
                const permission = permissionFromValue(native_event.detail_value) orelse continue;
                state.app.dispatchPlatformEvent(.{ .permission_result = .{
                    .request_id = native_event.request_id,
                    .permission = permission,
                    .granted = native_event.granted,
                } });
            },
            .file_selected => state.app.dispatchPlatformEvent(.{ .file_selected = .{
                .request_id = native_event.request_id,
                .uri = native_event.text(),
            } }),
            .file_selection_cancelled => state.app.dispatchPlatformEvent(.{
                .file_selection_cancelled = native_event.request_id,
            }),
            .accessibility_action => {
                const semantic_action: zapp.ui.SemanticAction = switch (native_event.action_value) {
                    @intFromEnum(zapp.platform.android.AccessibilityAction.focus) => .focus,
                    @intFromEnum(zapp.platform.android.AccessibilityAction.click) => .activate,
                    @intFromEnum(zapp.platform.android.AccessibilityAction.increment) => .increment,
                    @intFromEnum(zapp.platform.android.AccessibilityAction.decrement) => .decrement,
                    @intFromEnum(zapp.platform.android.AccessibilityAction.set_text) => .set_text,
                    @intFromEnum(zapp.platform.android.AccessibilityAction.expand) => .expand,
                    @intFromEnum(zapp.platform.android.AccessibilityAction.collapse) => .collapse,
                    @intFromEnum(zapp.platform.android.AccessibilityAction.scroll_forward) => .scroll_forward,
                    @intFromEnum(zapp.platform.android.AccessibilityAction.scroll_backward) => .scroll_backward,
                    else => continue,
                };
                const actions = zapp.ui.handleSemanticAction(
                    &state.app.model,
                    native_event.element_id,
                    semantic_action,
                    native_event.text(),
                );
                for (actions) |action| state.app.dispatch(action);
            },
            .file_read_completed => state.app.dispatchPlatformEvent(.{ .file_read_completed = .{
                .request_id = native_event.request_id,
                .data = native_event.payload(),
                .truncated = native_event.truncated,
                .display_name = native_event.displayName(),
                .mime_type = native_event.mimeType(),
                .size = native_event.fileSize(),
            } }),
            .file_read_failed => {
                const error_kind = fileReadErrorFromValue(native_event.detail_value) orelse .io;
                state.app.dispatchPlatformEvent(.{ .file_read_failed = .{
                    .request_id = native_event.request_id,
                    .error_kind = error_kind,
                } });
            },
            .file_stream_chunk => state.app.dispatchPlatformEvent(.{ .file_stream_chunk = .{
                .request_id = native_event.request_id,
                .offset = native_event.file_size,
                .data = native_event.payload(),
            } }),
            .file_stream_completed => state.app.dispatchPlatformEvent(.{ .file_stream_completed = .{
                .request_id = native_event.request_id,
                .total_bytes = native_event.file_size,
            } }),
            .file_stream_failed => {
                const error_kind = fileReadErrorFromValue(native_event.detail_value) orelse .io;
                state.app.dispatchPlatformEvent(.{ .file_stream_failed = .{
                    .request_id = native_event.request_id,
                    .error_kind = error_kind,
                } });
            },
            .file_stream_cancelled => state.app.dispatchPlatformEvent(.{ .file_stream_cancelled = .{
                .request_id = native_event.request_id,
                .total_bytes = native_event.file_size,
            } }),
            .native_crash_recovered => state.app.dispatchPlatformEvent(.{ .native_crash_recovered = .{
                .signal_number = native_event.detail_value,
                .signal_code = native_event.action_value,
                .architecture = crashArchitectureFromValue(native_event.crash_architecture),
                .pc_in_app = native_event.crash_flags & 1 != 0,
                .relative_pc = native_event.request_id,
                .absolute_pc = native_event.crash_absolute_pc,
                .fault_address = native_event.file_size,
                .process_id = native_event.crash_process_id,
                .thread_id = native_event.crash_thread_id,
                .timestamp_seconds = native_event.crash_timestamp_seconds,
                .build_id_length = @min(native_event.crash_build_id_length, native_event.crash_build_id.len),
                .build_id = native_event.crash_build_id,
            } }),
        }
    }
}

fn processPlatformRequests() void {
    while (state.app.takePlatformRequest()) |request| {
        switch (request) {
            .request_permission => |permission_request| {
                const started = if (comptime builtin.abi.isAndroid())
                    zapp.platform.android.requestPermission(
                        permission_request.request_id,
                        @intFromEnum(permission_request.permission),
                    )
                else
                    false;
                if (!started) state.app.dispatchPlatformEvent(.{ .permission_result = .{
                    .request_id = permission_request.request_id,
                    .permission = permission_request.permission,
                    .granted = false,
                } });
            },
            .open_file => |file_request| {
                const started = if (comptime builtin.abi.isAndroid())
                    zapp.platform.android.openFile(file_request.request_id)
                else
                    false;
                if (!started) state.app.dispatchPlatformEvent(.{
                    .file_selection_cancelled = file_request.request_id,
                });
            },
            .read_file => |file_request| {
                const started = if (comptime builtin.abi.isAndroid())
                    zapp.platform.android.readFile(
                        file_request.request_id,
                        file_request.uri(),
                        file_request.max_bytes,
                    )
                else
                    false;
                if (!started) state.app.dispatchPlatformEvent(.{ .file_read_failed = .{
                    .request_id = file_request.request_id,
                    .error_kind = .unsupported,
                } });
            },
            .stream_file => |stream_request| {
                const started = if (comptime builtin.abi.isAndroid())
                    zapp.platform.android.streamFile(
                        stream_request.request_id,
                        stream_request.uri(),
                        stream_request.chunk_bytes,
                    )
                else
                    false;
                if (!started) state.app.dispatchPlatformEvent(.{ .file_stream_failed = .{
                    .request_id = stream_request.request_id,
                    .error_kind = .unsupported,
                } });
            },
            .cancel_file_stream => |request_id| {
                const cancelled = if (comptime builtin.abi.isAndroid())
                    zapp.platform.android.cancelFileStream(request_id)
                else
                    false;
                if (!cancelled) state.app.dispatchPlatformEvent(.{ .file_stream_failed = .{
                    .request_id = request_id,
                    .error_kind = .unsupported,
                } });
            },
        }
    }
}

fn permissionFromValue(value: c_int) ?zapp.platform.Permission {
    return switch (value) {
        @intFromEnum(zapp.platform.Permission.camera) => .camera,
        @intFromEnum(zapp.platform.Permission.microphone) => .microphone,
        @intFromEnum(zapp.platform.Permission.notifications) => .notifications,
        @intFromEnum(zapp.platform.Permission.media) => .media,
        else => null,
    };
}

fn fileReadErrorFromValue(value: c_int) ?zapp.platform.FileReadError {
    return switch (value) {
        @intFromEnum(zapp.platform.FileReadError.invalid_uri) => .invalid_uri,
        @intFromEnum(zapp.platform.FileReadError.not_found) => .not_found,
        @intFromEnum(zapp.platform.FileReadError.permission_denied) => .permission_denied,
        @intFromEnum(zapp.platform.FileReadError.io) => .io,
        @intFromEnum(zapp.platform.FileReadError.unsupported) => .unsupported,
        else => null,
    };
}

fn crashArchitectureFromValue(value: u32) zapp.platform.CrashArchitecture {
    return switch (value) {
        @intFromEnum(zapp.platform.CrashArchitecture.arm64) => .arm64,
        @intFromEnum(zapp.platform.CrashArchitecture.x86_64) => .x86_64,
        else => .unknown,
    };
}

fn setKeyboardVisible(visible: bool) void {
    if (comptime builtin.abi.isAndroid()) {
        zapp.platform.android.setImeVisible(visible);
    } else {
        sapp.showKeyboard(visible);
    }
}

export fn event(ev: [*c]const sapp.Event) void {
    if (ev == null) return;
    const current = ev[0];

    switch (current.type) {
        .RESIZED => state.app.dispatch(.{ .resized = .{
            .width = current.framebuffer_width,
            .height = current.framebuffer_height,
            .dpi_scale = sapp.dpiScale(),
        } }),
        .MOUSE_MOVE, .MOUSE_DOWN, .MOUSE_UP => state.app.dispatch(.{ .pointer_changed = .{
            .x = current.mouse_x,
            .y = current.mouse_y,
            .down = switch (current.type) {
                .MOUSE_DOWN => true,
                .MOUSE_UP => false,
                else => state.app.model.pointer_down,
            },
        } }),
        .MOUSE_SCROLL => state.app.dispatch(.{ .scroll_changed = .{
            .x = current.scroll_x,
            .y = current.scroll_y,
        } }),
        .KEY_DOWN => {
            if (current.key_code == .ESCAPE and !current.key_repeat) {
                state.app.dispatch(.back_requested);
            } else if (current.key_code == .TAB and !current.key_repeat) {
                if (current.modifiers & sapp.modifier_shift != 0) {
                    state.app.dispatch(.focus_previous_requested);
                } else {
                    state.app.dispatch(.focus_next_requested);
                }
            } else if (state.app.model.text_field_focused) {
                const command_modifier = current.modifiers & (sapp.modifier_ctrl | sapp.modifier_super) != 0;
                const selecting = current.modifiers & sapp.modifier_shift != 0;
                if (command_modifier and current.key_code == .A and !current.key_repeat) {
                    state.app.dispatch(.text_select_all);
                } else if (command_modifier and current.key_code == .C and !current.key_repeat) {
                    copyTextSelectionToClipboard(&state.app.model);
                } else if (command_modifier and current.key_code == .X and !current.key_repeat) {
                    copyTextSelectionToClipboard(&state.app.model);
                    state.app.dispatch(.text_delete_selection);
                } else if (current.key_code == .BACKSPACE) {
                    state.app.dispatch(.text_backspace);
                } else if (current.key_code == .DELETE) {
                    state.app.dispatch(.text_delete_selection);
                } else if (current.key_code == .LEFT) {
                    state.app.dispatch(.{ .text_cursor_moved = .{ .direction = -1, .selecting = selecting } });
                } else if (current.key_code == .RIGHT) {
                    state.app.dispatch(.{ .text_cursor_moved = .{ .direction = 1, .selecting = selecting } });
                } else if (current.key_code == .HOME) {
                    state.app.dispatch(.{ .text_cursor_home = selecting });
                } else if (current.key_code == .END) {
                    state.app.dispatch(.{ .text_cursor_end = selecting });
                } else if (current.key_code == .ENTER and !current.key_repeat) {
                    state.app.dispatch(.text_submitted);
                }
            } else if (!current.key_repeat and (current.key_code == .ENTER or current.key_code == .SPACE)) {
                state.app.dispatch(.focused_control_activate_requested);
            } else if (current.key_code == .UP) {
                state.app.dispatch(.focused_control_up_requested);
            } else if (current.key_code == .DOWN) {
                state.app.dispatch(.focused_control_down_requested);
            } else if (current.key_code == .LEFT) {
                state.app.dispatch(.focused_control_left_requested);
            } else if (current.key_code == .RIGHT) {
                state.app.dispatch(.focused_control_right_requested);
            }
        },
        .CHAR => {
            if (state.app.model.text_field_focused and current.char_code >= 32) {
                var encoded: [4]u8 = undefined;
                const length = std.unicode.utf8Encode(@intCast(current.char_code), &encoded) catch 0;
                if (length > 0) state.app.dispatch(.{ .text_inserted = encoded[0..length] });
            }
        },
        .CLIPBOARD_PASTED => {
            if (state.app.model.text_field_focused) {
                state.app.dispatch(.{ .text_inserted = sapp.getClipboardString() });
            }
        },
        .TOUCHES_BEGAN, .TOUCHES_MOVED, .TOUCHES_ENDED, .TOUCHES_CANCELLED => {
            if (current.num_touches > 0) {
                const touch = current.touches[0];
                state.app.dispatch(.{ .pointer_changed = .{
                    .x = touch.pos_x,
                    .y = touch.pos_y,
                    .down = current.type == .TOUCHES_BEGAN or current.type == .TOUCHES_MOVED,
                } });
            } else if (current.type == .TOUCHES_ENDED or current.type == .TOUCHES_CANCELLED) {
                state.app.dispatch(.{ .pointer_changed = .{
                    .x = state.app.model.pointer_x,
                    .y = state.app.model.pointer_y,
                    .down = false,
                } });
            }
        },
        .SUSPENDED => state.app.dispatch(.suspended),
        .RESUMED => state.app.dispatch(.resumed),
        else => {},
    }
}

fn copyTextSelectionToClipboard(model: *const zapp.app.Model) void {
    const selected = model.selectedText();
    if (selected.len == 0) return;
    var clipboard: [257:0]u8 = @splat(0);
    const length = @min(selected.len, clipboard.len - 1);
    @memcpy(clipboard[0..length], selected[0..length]);
    sapp.setClipboardString(clipboard[0..length :0]);
}

export fn cleanup() void {
    if (comptime builtin.abi.isAndroid()) zapp.platform.android.reset();
    zapp.ui.shutdown();
    state.renderer.shutdown();
}

fn appDesc() sapp.Desc {
    return .{
        .init_cb = init,
        .frame_cb = frame,
        .event_cb = event,
        .cleanup_cb = cleanup,
        .width = 1280,
        .height = 720,
        .high_dpi = true,
        .icon = .{ .sokol_default = true },
        .depth_format = .NONE,
        .enable_clipboard = true,
        .clipboard_size = 16 * 1024,
        .window_title = "zapp",
        .logger = .{ .func = slog.func },
        .win32 = .{ .console_attach = true },
    };
}

pub fn main() void {
    sapp.run(appDesc());
}

// Android's sokol_app backend owns ANativeActivity_onCreate and calls this
// entry point. It must not be exported on desktop, where sapp.run() is used.
fn androidMain(_: i32, _: [*c][*c]u8) callconv(.c) sapp.Desc {
    return appDesc();
}

comptime {
    if (builtin.abi.isAndroid()) {
        @export(&androidMain, .{ .name = "sokol_main" });
    }
}
