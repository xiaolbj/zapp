const clay = @import("zclay");
const interaction = @import("interaction.zig");
const label = @import("label.zig");
const semantics = @import("../semantics.zig");
const theme = @import("../theme.zig");

pub const Config = struct {
    id: []const u8,
    text: []const u8,
    checked: bool,
    width: f32 = 260,
    disabled: bool = false,
    focused: bool = false,
    semantic_registry: ?*semantics.Registry = null,
};

pub fn draw(state: *interaction.State, input: interaction.Input, config: Config) bool {
    const id = clay.ElementId.ID(config.id);
    if (config.semantic_registry) |registry| _ = registry.add(.{
        .element_id = id.id,
        .role = .checkbox,
        .label = config.text,
        .checked = config.checked,
        .disabled = config.disabled,
        .focused = config.focused,
    });
    const result = interaction.update(state, id.id, clay.pointerOver(id), input, config.disabled);
    const box_color: clay.Color = if (config.disabled)
        theme.controls.surface_disabled_soft
    else if (config.checked)
        if (result.active) theme.controls.accent_pressed else theme.controls.accent
    else if (result.hovered or config.focused)
        theme.controls.control_inactive_hover
    else
        theme.controls.control_inactive;

    clay.UI()(.{
        .id = id,
        .layout = .{
            .sizing = .{ .w = .fixed(config.width), .h = .fixed(40) },
            .child_gap = theme.controls.gap_medium,
            .child_alignment = .{ .y = .center },
        },
        .border = .{
            .color = theme.controls.focus,
            .width = if (config.focused) .outside(theme.controls.focus_width) else .{},
        },
        .corner_radius = .all(theme.controls.radius_small),
    })({
        clay.UI()(.{
            .layout = .{
                .sizing = .{ .w = .fixed(24), .h = .fixed(24) },
                .child_alignment = .center,
            },
            .background_color = box_color,
            .corner_radius = .all(theme.controls.radius_small),
        })({
            if (config.checked) label.draw("✓", .{
                .font_size = 17,
                .color = if (config.disabled) theme.controls.text_disabled else theme.controls.on_accent,
            });
        });
        label.draw(config.text, .{
            .color = if (config.disabled) theme.controls.text_disabled else theme.controls.text_secondary,
        });
    });

    return result.clicked or (config.focused and input.activate_pressed and !config.disabled);
}
