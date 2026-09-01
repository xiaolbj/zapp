const clay = @import("zclay");
const interaction = @import("interaction.zig");
const label = @import("label.zig");

pub const Config = struct {
    id: []const u8,
    text: []const u8,
    checked: bool,
    width: f32 = 260,
    disabled: bool = false,
};

pub fn draw(state: *interaction.State, input: interaction.Input, config: Config) bool {
    const id = clay.ElementId.ID(config.id);
    const result = interaction.update(state, id.id, clay.pointerOver(id), input, config.disabled);
    const box_color: clay.Color = if (config.disabled)
        .{ 68, 78, 94, 255 }
    else if (config.checked)
        if (result.active) .{ 30, 85, 164, 255 } else .{ 42, 111, 204, 255 }
    else if (result.hovered)
        .{ 74, 91, 117, 255 }
    else
        .{ 53, 66, 87, 255 };

    clay.UI()(.{
        .id = id,
        .layout = .{
            .sizing = .{ .w = .fixed(config.width), .h = .fixed(40) },
            .child_gap = 12,
            .child_alignment = .{ .y = .center },
        },
    })({
        clay.UI()(.{
            .layout = .{
                .sizing = .{ .w = .fixed(24), .h = .fixed(24) },
                .child_alignment = .center,
            },
            .background_color = box_color,
            .corner_radius = .all(6),
        })({
            if (config.checked) label.draw("✓", .{
                .font_size = 17,
                .color = if (config.disabled) .{ 164, 173, 188, 255 } else .{ 250, 252, 255, 255 },
            });
        });
        label.draw(config.text, .{
            .color = if (config.disabled) .{ 132, 143, 160, 255 } else .{ 222, 231, 244, 255 },
        });
    });

    return result.clicked;
}
