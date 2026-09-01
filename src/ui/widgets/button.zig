const clay = @import("zclay");
const label = @import("label.zig");
const interaction = @import("interaction.zig");
const semantics = @import("../semantics.zig");
const theme = @import("../theme.zig");

pub const State = interaction.State;
pub const Input = interaction.Input;

pub const Config = struct {
    id: []const u8,
    text: []const u8,
    width: f32 = 200,
    disabled: bool = false,
    focused: bool = false,
    semantic_registry: ?*semantics.Registry = null,
    normal_color: clay.Color = theme.controls.accent,
    hover_color: clay.Color = theme.controls.accent_hover,
    pressed_color: clay.Color = theme.controls.accent_pressed,
    disabled_color: clay.Color = theme.controls.surface_disabled,
};

pub fn draw(state: *State, input: Input, config: Config) bool {
    const id = clay.ElementId.ID(config.id);
    if (config.semantic_registry) |registry| _ = registry.add(.{
        .element_id = id.id,
        .role = .button,
        .label = config.text,
        .disabled = config.disabled,
        .focused = config.focused,
    });
    const result = interaction.update(state, id.id, clay.pointerOver(id), input, config.disabled);
    const color = if (config.disabled)
        config.disabled_color
    else if (result.active)
        config.pressed_color
    else if (result.hovered or config.focused)
        config.hover_color
    else
        config.normal_color;

    clay.UI()(.{
        .id = id,
        .layout = .{
            .sizing = .{ .w = .fixed(config.width), .h = .fixed(theme.controls.control_height) },
            .padding = .axes(20, 12),
            .child_alignment = .center,
        },
        .background_color = color,
        .corner_radius = .all(theme.controls.radius_medium),
        .border = .{
            .color = theme.controls.focus,
            .width = if (config.focused) .outside(theme.controls.focus_width) else .{},
        },
    })({
        label.draw(config.text, .{
            .font_size = 16,
            .color = if (config.disabled) theme.controls.text_disabled else theme.controls.on_accent,
        });
    });

    return result.clicked or (config.focused and input.activate_pressed and !config.disabled);
}
