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
    expanded: bool,
    width: f32 = 260,
    disabled: bool = false,
    focused_id: ?u32 = null,
    semantic_label: []const u8 = "Select",
    semantic_registry: ?*semantics.Registry = null,
};

pub const Result = struct {
    selected_index: ?usize = null,
    expanded: ?bool = null,
    focus_id: ?u32 = null,
};

/// Draws a controlled single-choice select. The caller owns both the selected
/// index and expanded state so opening, selection, and accessibility actions
/// all travel through the same App reducer path.
pub fn draw(state: *interaction.State, input: interaction.Input, config: Config) Result {
    var output: Result = .{};
    const trigger_id = triggerId(config.id);
    const container_id = clay.ElementId.IDI(config.id, std.math.maxInt(u32) - 1);
    const selected_index = boundedIndex(config.selected_index, config.items.len);
    const selected_text = if (selected_index) |index| config.items[index].text else "未选择";
    const trigger_pointer = interaction.update(
        state,
        trigger_id.id,
        clay.pointerOver(trigger_id),
        input,
        config.disabled,
    );
    const trigger_focused = config.focused_id == trigger_id.id;

    if (config.semantic_registry) |registry| _ = registry.add(.{
        .element_id = trigger_id.id,
        .role = .combo_box,
        .label = config.semantic_label,
        .value_text = selected_text,
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
        const trigger_background: clay.Color = if (config.disabled)
            theme.controls.input_disabled
        else if (trigger_pointer.active)
            theme.controls.surface_focused
        else if (trigger_pointer.hovered or trigger_focused or config.expanded)
            theme.controls.input_hover
        else
            theme.controls.surface;
        clay.UI()(.{
            .id = trigger_id,
            .layout = .{
                .sizing = .{ .w = .fixed(config.width), .h = .fixed(theme.controls.control_height) },
                .padding = .axes(14, 10),
                .child_gap = theme.controls.gap_small,
                .child_alignment = .{ .y = .center },
            },
            .background_color = trigger_background,
            .corner_radius = .all(theme.controls.radius_medium),
            .border = .{
                .color = theme.controls.focus,
                .width = if (trigger_focused) .outside(theme.controls.focus_width) else .{},
            },
        })({
            clay.UI()(.{ .layout = .{ .sizing = .{ .w = .grow, .h = .fit } } })({
                label.draw(selected_text, .{
                    .font_size = 16,
                    .color = if (config.disabled) theme.controls.text_disabled else theme.controls.text_secondary,
                });
            });
            label.draw(if (config.expanded) "▲" else "▼", .{
                .font_size = 14,
                .color = if (config.disabled) theme.controls.text_disabled else theme.controls.text_muted,
            });
        });

        if (config.expanded) {
            for (config.items, 0..) |item, index| {
                const option_id = optionId(config.id, index);
                const focused = config.focused_id == option_id.id;
                const selected = selected_index == index;
                const pointer = interaction.update(
                    state,
                    option_id.id,
                    clay.pointerOver(option_id),
                    input,
                    config.disabled,
                );
                if (config.semantic_registry) |registry| _ = registry.add(.{
                    .element_id = option_id.id,
                    .role = .option,
                    .label = item.text,
                    .checked = selected,
                    .disabled = config.disabled,
                    .focused = focused,
                    .selected = selected,
                });
                const background: clay.Color = if (config.disabled)
                    theme.controls.input_disabled
                else if (pointer.active)
                    theme.controls.accent_pressed
                else if (selected)
                    theme.controls.navigation_active
                else if (pointer.hovered or focused)
                    theme.controls.surface_hover
                else
                    theme.controls.surface;
                clay.UI()(.{
                    .id = option_id,
                    .layout = .{
                        .sizing = .{ .w = .fixed(config.width), .h = .fixed(42) },
                        .padding = .axes(14, 9),
                        .child_alignment = .{ .y = .center },
                    },
                    .background_color = background,
                    .corner_radius = .all(theme.controls.radius_small),
                    .border = .{
                        .color = theme.controls.focus,
                        .width = if (focused) .outside(theme.controls.focus_width) else .{},
                    },
                })({
                    label.draw(item.text, .{
                        .font_size = 15,
                        .color = if (config.disabled) theme.controls.text_disabled else theme.controls.text_secondary,
                    });
                });

                if (pointer.clicked) selectOption(&output, config.id, index);
                if (!config.disabled and focused) {
                    if (input.activate_pressed) {
                        selectOption(&output, config.id, index);
                    } else if (input.up_pressed != input.down_pressed) {
                        const target = adjacentIndex(index, config.items.len, if (input.up_pressed) -1 else 1);
                        output.focus_id = optionId(config.id, target).id;
                    } else if (input.left_pressed) {
                        output.expanded = false;
                        output.focus_id = trigger_id.id;
                    }
                }
            }
        }
    });

    if (config.disabled and config.expanded) {
        output.expanded = false;
        output.focus_id = trigger_id.id;
    } else if (trigger_pointer.clicked or
        (trigger_focused and input.activate_pressed and !config.disabled))
    {
        output.expanded = !config.expanded;
        output.focus_id = trigger_id.id;
    } else if (!config.disabled and trigger_focused and config.items.len > 0 and
        input.up_pressed != input.down_pressed)
    {
        if (config.expanded) {
            const target = selected_index orelse 0;
            output.focus_id = optionId(config.id, target).id;
        } else {
            const current = selected_index orelse 0;
            output.selected_index = adjacentIndex(
                current,
                config.items.len,
                if (input.up_pressed) -1 else 1,
            );
        }
    } else if (config.expanded and input.pressed and !clay.pointerOver(container_id)) {
        output.expanded = false;
        output.focus_id = trigger_id.id;
    }
    return output;
}

pub fn triggerId(select_id: []const u8) clay.ElementId {
    return clay.ElementId.IDI(select_id, std.math.maxInt(u32));
}

pub fn optionId(select_id: []const u8, index: usize) clay.ElementId {
    return clay.ElementId.IDI(select_id, @intCast(index));
}

fn selectOption(output: *Result, select_id: []const u8, index: usize) void {
    output.selected_index = index;
    output.expanded = false;
    output.focus_id = triggerId(select_id).id;
}

fn boundedIndex(index: usize, count: usize) ?usize {
    if (count == 0) return null;
    return @min(index, count - 1);
}

fn adjacentIndex(index: usize, count: usize, direction: i8) usize {
    if (count == 0) return 0;
    const current = @min(index, count - 1);
    if (direction < 0) return if (current == 0) count - 1 else current - 1;
    return (current + 1) % count;
}

test "select ids remain stable and distinct" {
    try std.testing.expect(triggerId("SortSelect").id != optionId("SortSelect", 0).id);
    try std.testing.expect(optionId("SortSelect", 0).id != optionId("SortSelect", 1).id);
}

test "select index helpers bound and wrap" {
    try std.testing.expectEqual(@as(?usize, null), boundedIndex(4, 0));
    try std.testing.expectEqual(@as(?usize, 2), boundedIndex(9, 3));
    try std.testing.expectEqual(@as(usize, 2), adjacentIndex(0, 3, -1));
    try std.testing.expectEqual(@as(usize, 0), adjacentIndex(2, 3, 1));
}
