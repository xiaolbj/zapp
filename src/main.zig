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
    for (ui_frame.actions) |action| state.app.dispatch(action);
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
