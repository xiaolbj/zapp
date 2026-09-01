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
    const track_color: clay.Color = if (config.disabled)
        .{ 61, 70, 84, 255 }
    else if (config.checked)
        if (result.active) .{ 30, 85, 164, 255 } else .{ 42, 111, 204, 255 }
    else if (result.hovered)
        .{ 79, 94, 116, 255 }
    else
        .{ 55, 67, 85, 255 };

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
                .sizing = .{ .w = .fixed(52), .h = .fixed(30) },
                .padding = .all(4),
                .child_alignment = .{
                    .x = if (config.checked) .right else .left,
                    .y = .center,
                },
            },
            .background_color = track_color,
            .corner_radius = .all(15),
        })({
            clay.UI()(.{
                .layout = .{ .sizing = .{ .w = .fixed(22), .h = .fixed(22) } },
                .background_color = if (config.disabled) .{ 156, 164, 176, 255 } else .{ 247, 250, 255, 255 },
                .corner_radius = .all(11),
            })({});
        });
        label.draw(config.text, .{
            .color = if (config.disabled) .{ 132, 143, 160, 255 } else .{ 222, 231, 244, 255 },
        });
    });

    return result.clicked;
}
