const clay = @import("zclay");
const label = @import("label.zig");
const interaction = @import("interaction.zig");

pub const State = interaction.State;
pub const Input = interaction.Input;

pub const Config = struct {
    id: []const u8,
    text: []const u8,
    width: f32 = 200,
    disabled: bool = false,
    focused: bool = false,
    normal_color: clay.Color = .{ 42, 111, 204, 255 },
    hover_color: clay.Color = .{ 55, 132, 229, 255 },
    pressed_color: clay.Color = .{ 30, 85, 164, 255 },
    disabled_color: clay.Color = .{ 64, 75, 94, 255 },
};

pub fn draw(state: *State, input: Input, config: Config) bool {
    const id = clay.ElementId.ID(config.id);
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
            .sizing = .{ .w = .fixed(config.width), .h = .fixed(48) },
            .padding = .axes(20, 12),
            .child_alignment = .center,
        },
        .background_color = color,
        .corner_radius = .all(10),
    })({
        label.draw(config.text, .{
            .font_size = 16,
            .color = if (config.disabled) .{ 154, 164, 181, 255 } else .{ 248, 251, 255, 255 },
        });
    });

    return result.clicked or (config.focused and input.activate_pressed and !config.disabled);
}
