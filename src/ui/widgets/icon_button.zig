const clay = @import("zclay");
const interaction = @import("interaction.zig");
const label = @import("label.zig");
const theme = @import("../theme.zig");

pub const Config = struct {
    id: []const u8,
    icon: []const u8,
    size: f32 = 44,
    disabled: bool = false,
    focused: bool = false,
};

pub fn draw(state: *interaction.State, input: interaction.Input, config: Config) bool {
    const id = clay.ElementId.ID(config.id);
    const result = interaction.update(state, id.id, clay.pointerOver(id), input, config.disabled);
    const color: clay.Color = if (config.disabled)
        theme.controls.surface_disabled
    else if (result.active)
        theme.controls.accent_pressed
    else if (result.hovered or config.focused)
        theme.controls.accent_hover
    else
        theme.controls.accent;

    clay.UI()(.{
        .id = id,
        .layout = .{
            .sizing = .{ .w = .fixed(config.size), .h = .fixed(config.size) },
            .child_alignment = .center,
        },
        .background_color = color,
        .corner_radius = .all(config.size * 0.5),
        .border = .{
            .color = theme.controls.focus,
            .width = if (config.focused) .outside(theme.controls.focus_width) else .{},
        },
    })({
        label.draw(config.icon, .{
            .font_size = 24,
            .color = if (config.disabled) theme.controls.text_disabled else theme.controls.on_accent,
        });
    });

    return result.clicked or (config.focused and input.activate_pressed and !config.disabled);
}
