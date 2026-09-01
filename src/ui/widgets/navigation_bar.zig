const clay = @import("zclay");
const interaction = @import("interaction.zig");
const label = @import("label.zig");

pub const Item = struct {
    text: []const u8,
};

pub const Config = struct {
    id: []const u8,
    items: []const Item,
    selected_index: usize,
    item_width: f32 = 180,
    direction: clay.LayoutDirection = .top_to_bottom,
    disabled: bool = false,
};

pub fn draw(state: *interaction.State, input: interaction.Input, config: Config) ?usize {
    var selected: ?usize = null;
    clay.UI()(.{
        .layout = .{
            .sizing = .fit,
            .child_gap = 6,
            .direction = config.direction,
        },
    })({
        for (config.items, 0..) |item, index| {
            const id = clay.ElementId.IDI(config.id, @intCast(index));
            const result = interaction.update(state, id.id, clay.pointerOver(id), input, config.disabled);
            const active = index == config.selected_index;
            const background: clay.Color = if (config.disabled)
                .{ 35, 43, 56, 255 }
            else if (active)
                .{ 42, 91, 153, 255 }
            else if (result.hovered)
                .{ 37, 54, 79, 255 }
            else
                .{ 0, 0, 0, 0 };

            clay.UI()(.{
                .id = id,
                .layout = .{
                    .sizing = .{ .w = .fixed(config.item_width), .h = .fixed(42) },
                    .padding = .axes(12, 10),
                    .child_alignment = .{ .y = .center },
                },
                .background_color = background,
                .corner_radius = .all(8),
            })({
                label.draw(item.text, .{
                    .font_size = 15,
                    .color = if (active) .{ 241, 247, 255, 255 } else .{ 163, 183, 211, 255 },
                });
            });
            if (result.clicked) selected = index;
        }
    });
    return selected;
}
