const std = @import("std");
const clay = @import("zclay");
const interaction = @import("interaction.zig");
const label = @import("label.zig");
const semantics = @import("../semantics.zig");
const theme = @import("../theme.zig");

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
    focused_id: ?u32 = null,
    semantic_label: []const u8 = "Navigation",
    semantic_registry: ?*semantics.Registry = null,
};

pub fn draw(state: *interaction.State, input: interaction.Input, config: Config) ?usize {
    var selected: ?usize = null;
    const navigation_id = clay.ElementId.IDI(config.id, std.math.maxInt(u32));
    if (config.semantic_registry) |registry| _ = registry.add(.{
        .element_id = navigation_id.id,
        .role = .navigation,
        .label = config.semantic_label,
        .disabled = config.disabled,
    });
    clay.UI()(.{
        .id = navigation_id,
        .layout = .{
            .sizing = .fit,
            .child_gap = theme.controls.radius_small,
            .direction = config.direction,
        },
    })({
        for (config.items, 0..) |item, index| {
            const id = clay.ElementId.IDI(config.id, @intCast(index));
            const result = interaction.update(state, id.id, clay.pointerOver(id), input, config.disabled);
            const active = index == config.selected_index;
            const focused = config.focused_id == id.id;
            if (config.semantic_registry) |registry| _ = registry.add(.{
                .element_id = id.id,
                .role = .navigation_item,
                .label = item.text,
                .disabled = config.disabled,
                .focused = focused,
                .selected = active,
            });
            const background: clay.Color = if (config.disabled)
                theme.controls.input_disabled
            else if (active)
                theme.controls.navigation_active
            else if (result.hovered or focused)
                theme.controls.surface_hover
            else
                theme.controls.transparent;

            clay.UI()(.{
                .id = id,
                .layout = .{
                    .sizing = .{ .w = .fixed(config.item_width), .h = .fixed(42) },
                    .padding = .axes(12, 10),
                    .child_alignment = .{ .y = .center },
                },
                .background_color = background,
                .corner_radius = .all(theme.controls.gap_small),
                .border = .{
                    .color = theme.controls.focus,
                    .width = if (focused) .outside(theme.controls.focus_width) else .{},
                },
            })({
                label.draw(item.text, .{
                    .font_size = 15,
                    .color = if (active) theme.controls.on_accent else theme.controls.text_navigation,
                });
            });
            if (result.clicked or (focused and input.activate_pressed and !config.disabled)) selected = index;
        }
    });
    return selected;
}

test "navigation container id does not collide with first item" {
    const container = clay.ElementId.IDI("MainNavigation", std.math.maxInt(u32));
    const first_item = clay.ElementId.IDI("MainNavigation", 0);
    try std.testing.expect(container.id != first_item.id);
}
