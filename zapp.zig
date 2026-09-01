pub const app = @import("src/app/app.zig");
pub const platform = @import("src/platform/platform.zig");
pub const render = @import("src/render/clay_renderer.zig");
pub const text = @import("src/text/font.zig");
pub const ui = @import("src/ui/root.zig");

test {
    _ = app;
    _ = platform;
    _ = text;
    _ = ui;
}
