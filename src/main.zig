const std = @import("std");
const sokol = @import("sokol");
const zapp = @import("zapp");

const sapp = sokol.app;
const slog = sokol.log;
const builtin = @import("builtin");

const App = zapp.app.App;
const ClayRenderer = zapp.render.ClayRenderer;

const state = struct {
    var app: App = .{};
    var renderer: ClayRenderer = .{};
};

export fn init() void {
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
    state.app.dispatch(.{ .tick = sapp.frameDuration() });
    const ui_frame = zapp.ui.build(&state.app.model);
    const keyboard_was_visible = state.app.model.text_field_focused;
    for (ui_frame.actions) |action| state.app.dispatch(action);
    if (keyboard_was_visible != state.app.model.text_field_focused) {
        sapp.showKeyboard(state.app.model.text_field_focused);
    }
    state.app.dispatch(.input_consumed);
    state.renderer.draw(ui_frame);
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
