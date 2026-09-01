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
    _ = @import("src/ui/focus_manager.zig");
    _ = @import("src/ui/widgets/button.zig");
    _ = @import("src/ui/widgets/card.zig");
    _ = @import("src/ui/widgets/checkbox.zig");
    _ = @import("src/ui/widgets/divider.zig");
    _ = @import("src/ui/widgets/dialog.zig");
    _ = @import("src/ui/widgets/icon_button.zig");
    _ = @import("src/ui/widgets/interaction.zig");
    _ = @import("src/ui/widgets/label.zig");
    _ = @import("src/ui/widgets/navigation_bar.zig");
    _ = @import("src/ui/widgets/progress_bar.zig");
    _ = @import("src/ui/widgets/scroll_view.zig");
    _ = @import("src/ui/widgets/slider.zig");
    _ = @import("src/ui/widgets/switch.zig");
    _ = @import("src/ui/widgets/text_field.zig");
    _ = @import("src/ui/widgets/toast.zig");
}
