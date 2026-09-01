const std = @import("std");
const clay = @import("zclay");
const interaction = @import("interaction.zig");
const label = @import("label.zig");
const semantics = @import("../semantics.zig");
const theme = @import("../theme.zig");

pub const Item = struct {
    text: []const u8,
    disabled: bool = false,
};

pub const Config = struct {
    id: []const u8,
    text: []const u8,
    items: []const Item,
    expanded: bool,
    width: f32 = 220,
    disabled: bool = false,
    focused_id: ?u32 = null,
    semantic_label: []const u8 = "Menu",
    semantic_registry: ?*semantics.Registry = null,
};

pub const Result = struct {
    activated_index: ?usize = null,
    expanded: ?bool = null,
    focus_id: ?u32 = null,
};

/// Draws a controlled menu button. Opening moves focus to the first enabled
/// item; activation and every close path restore focus to the trigger.
pub fn draw(state: *interaction.State, input: interaction.Input, config: Config) Result {
    var output: Result = .{};
    const trigger_id = triggerId(config.id);
    const container_id = clay.ElementId.IDI(config.id, std.math.maxInt(u32) - 1);
    const list_id = clay.ElementId.IDI(config.id, std.math.maxInt(u32) - 2);
    const trigger_focused = config.focused_id == trigger_id.id;
    const trigger_pointer = interaction.update(
        state,
        trigger_id.id,
        clay.pointerOver(trigger_id),
        input,
        config.disabled,
    );

    if (config.semantic_registry) |registry| _ = registry.add(.{
        .element_id = trigger_id.id,
        .role = .button,
        .label = config.semantic_label,
        .disabled = config.disabled,
        .focused = trigger_focused,
        .expanded = config.expanded,
    });

    clay.UI()(.{
        .id = container_id,
        .layout = .{
            .sizing = .{ .w = .fixed(config.width), .h = .fit },
            .child_gap = theme.controls.gap_tiny,
            .direction = .top_to_bottom,
        },
    })({
        clay.UI()(.{
            .id = trigger_id,
            .layout = .{
                .sizing = .{ .w = .fixed(config.width), .h = .fixed(theme.controls.control_height) },
                .padding = .axes(14, 10),
                .child_gap = theme.controls.gap_small,
                .child_alignment = .{ .y = .center },
            },
            .background_color = if (config.disabled)
                theme.controls.input_disabled
            else if (trigger_pointer.active)
                theme.controls.accent_pressed
            else if (trigger_pointer.hovered or trigger_focused or config.expanded)
                theme.controls.input_hover
            else
                theme.controls.surface,
            .corner_radius = .all(theme.controls.radius_medium),
            .border = .{
                .color = theme.controls.focus,
                .width = if (trigger_focused) .outside(theme.controls.focus_width) else .{},
            },
        })({
            clay.UI()(.{ .layout = .{ .sizing = .{ .w = .grow, .h = .fit } } })({
                label.draw(config.text, .{
                    .font_size = 16,
                    .color = if (config.disabled) theme.controls.text_disabled else theme.controls.text_secondary,
                });
            });
            label.draw(if (config.expanded) "▲" else "▼", .{
                .font_size = 13,
                .color = if (config.disabled) theme.controls.text_disabled else theme.controls.text_muted,
            });
        });

        if (config.expanded) {
            if (config.semantic_registry) |registry| _ = registry.add(.{
                .element_id = list_id.id,
                .role = .menu,
                .label = config.semantic_label,
                .disabled = config.disabled,
            });
            clay.UI()(.{
                .id = list_id,
                .layout = .{
                    .sizing = .{ .w = .fixed(config.width), .h = .fit },
                    .child_gap = theme.controls.gap_tiny,
                    .direction = .top_to_bottom,
                },
                .background_color = theme.controls.surface,
                .corner_radius = .all(theme.controls.radius_medium),
            })(for (config.items, 0..) |item, index| {
                const id = itemId(config.id, index);
                const item_disabled = config.disabled or item.disabled;
                const focused = config.focused_id == id.id;
                const pointer = interaction.update(state, id.id, clay.pointerOver(id), input, item_disabled);
                if (config.semantic_registry) |registry| _ = registry.add(.{
                    .element_id = id.id,
                    .role = .menu_item,
                    .label = item.text,
                    .disabled = item_disabled,
                    .focused = focused,
                });

                clay.UI()(.{
                    .id = id,
                    .layout = .{
                        .sizing = .{ .w = .fixed(config.width), .h = .fixed(42) },
                        .padding = .axes(14, 9),
                        .child_alignment = .{ .y = .center },
                    },
                    .background_color = if (item_disabled)
                        theme.controls.input_disabled
                    else if (pointer.active)
                        theme.controls.accent_pressed
                    else if (pointer.hovered or focused)
                        theme.controls.surface_hover
                    else
                        theme.controls.surface,
                    .corner_radius = .all(theme.controls.radius_small),
                    .border = .{
                        .color = theme.controls.focus,
                        .width = if (focused) .outside(theme.controls.focus_width) else .{},
                    },
                })(label.draw(item.text, .{
                    .font_size = 15,
                    .color = if (item_disabled) theme.controls.text_disabled else theme.controls.text_secondary,
                }));

                if (pointer.clicked or (focused and !item_disabled and input.activate_pressed)) {
                    activate(&output, config.id, index);
                } else if (focused and !item_disabled) {
                    if (input.up_pressed != input.down_pressed) {
                        if (adjacentEnabled(config.items, index, if (input.up_pressed) -1 else 1)) |target| {
                            output.focus_id = itemId(config.id, target).id;
                        }
                    } else if (input.home_pressed) {
                        if (firstEnabled(config.items)) |target| output.focus_id = itemId(config.id, target).id;
                    } else if (input.end_pressed) {
                        if (lastEnabled(config.items)) |target| output.focus_id = itemId(config.id, target).id;
                    } else if (input.left_pressed) {
                        close(&output, config.id);
                    }
                }
            });
        }
    });

    if (config.disabled and config.expanded) {
        close(&output, config.id);
    } else if (trigger_pointer.clicked or (trigger_focused and input.activate_pressed and !config.disabled)) {
        output.expanded = !config.expanded;
        output.focus_id = if (!config.expanded)
            if (firstEnabled(config.items)) |index| itemId(config.id, index).id else trigger_id.id
        else
            trigger_id.id;
    } else if (!config.disabled and trigger_focused and config.items.len > 0 and
        input.up_pressed != input.down_pressed)
    {
        output.expanded = true;
        const target = if (input.up_pressed) lastEnabled(config.items) else firstEnabled(config.items);
        output.focus_id = if (target) |index| itemId(config.id, index).id else trigger_id.id;
    } else if (config.expanded and input.pressed and !clay.pointerOver(container_id)) {
        close(&output, config.id);
    }
    return output;
}

pub fn triggerId(menu_id: []const u8) clay.ElementId {
    return clay.ElementId.IDI(menu_id, std.math.maxInt(u32));
}

pub fn itemId(menu_id: []const u8, index: usize) clay.ElementId {
    return clay.ElementId.IDI(menu_id, @intCast(index));
}

pub fn firstEnabled(items: []const Item) ?usize {
    for (items, 0..) |item, index| if (!item.disabled) return index;
    return null;
}

pub fn lastEnabled(items: []const Item) ?usize {
    var index = items.len;
    while (index > 0) {
        index -= 1;
        if (!items[index].disabled) return index;
    }
    return null;
}

pub fn adjacentEnabled(items: []const Item, index: usize, direction: i8) ?usize {
    if (items.len == 0 or firstEnabled(items) == null) return null;
    var candidate = @min(index, items.len - 1);
    for (0..items.len) |_| {
        candidate = if (direction < 0)
            if (candidate == 0) items.len - 1 else candidate - 1
        else
            (candidate + 1) % items.len;
        if (!items[candidate].disabled) return candidate;
    }
    return null;
}

fn activate(output: *Result, menu_id: []const u8, index: usize) void {
    output.activated_index = index;
    close(output, menu_id);
}

fn close(output: *Result, menu_id: []const u8) void {
    output.expanded = false;
    output.focus_id = triggerId(menu_id).id;
}

test "menu ids remain stable and distinct" {
    try std.testing.expect(triggerId("ActionsMenu").id != itemId("ActionsMenu", 0).id);
    try std.testing.expect(itemId("ActionsMenu", 0).id != itemId("ActionsMenu", 1).id);
}

test "menu navigation skips disabled items and wraps" {
    const items = [_]Item{
        .{ .text = "Open" },
        .{ .text = "Rename", .disabled = true },
        .{ .text = "Archive" },
    };
    try std.testing.expectEqual(@as(?usize, 0), firstEnabled(&items));
    try std.testing.expectEqual(@as(?usize, 2), lastEnabled(&items));
    try std.testing.expectEqual(@as(?usize, 2), adjacentEnabled(&items, 0, 1));
    try std.testing.expectEqual(@as(?usize, 0), adjacentEnabled(&items, 2, 1));
    try std.testing.expectEqual(@as(?usize, 2), adjacentEnabled(&items, 0, -1));
}

test "menu with no enabled items has no navigation target" {
    const items = [_]Item{
        .{ .text = "A", .disabled = true },
        .{ .text = "B", .disabled = true },
    };
    try std.testing.expectEqual(@as(?usize, null), firstEnabled(&items));
    try std.testing.expectEqual(@as(?usize, null), lastEnabled(&items));
    try std.testing.expectEqual(@as(?usize, null), adjacentEnabled(&items, 0, 1));
}
