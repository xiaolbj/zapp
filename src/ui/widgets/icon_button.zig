const clay = @import("zclay");
const interaction = @import("interaction.zig");
const label = @import("label.zig");

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
        .{ 64, 75, 94, 255 }
    else if (result.active)
        .{ 30, 85, 164, 255 }
    else if (result.hovered or config.focused)
        .{ 55, 132, 229, 255 }
    else
        .{ 42, 111, 204, 255 };

    clay.UI()(.{
        .id = id,
        .layout = .{
            .sizing = .{ .w = .fixed(config.size), .h = .fixed(config.size) },
            .child_alignment = .center,
        },
        .background_color = color,
        .corner_radius = .all(config.size * 0.5),
    })({
        label.draw(config.icon, .{
            .font_size = 24,
            .color = if (config.disabled) .{ 154, 164, 181, 255 } else .{ 248, 251, 255, 255 },
        });
    });

    return result.clicked or (config.focused and input.activate_pressed and !config.disabled);
}
