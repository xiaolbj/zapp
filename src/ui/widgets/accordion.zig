const std = @import("std");
const clay = @import("zclay");
const interaction = @import("interaction.zig");
const label = @import("label.zig");
const semantics = @import("../semantics.zig");
const theme = @import("../theme.zig");

pub const Mode = enum {
    single,
    multiple,
};

pub const Item = struct {
    title: []const u8,
    disabled: bool = false,
};

pub const DrawPanelFn = *const fn (context: ?*anyopaque, index: usize) void;

pub const Config = struct {
    id: []const u8,
    items: []const Item,
    expanded_mask: u64,
    mode: Mode = .single,
    width: f32 = 320,
    disabled: bool = false,
    focused_id: ?u32 = null,
    semantic_label: []const u8 = "Accordion",
    semantic_registry: ?*semantics.Registry = null,
    draw_panel: ?DrawPanelFn = null,
    panel_context: ?*anyopaque = null,
};

pub const Result = struct {
    expanded_mask: ?u64 = null,
    focus_index: ?usize = null,
};

/// Draws a controlled accordion. Headers and panel visibility are owned by
/// the widget while panel content is composed by the caller callback.
pub fn draw(state: *interaction.State, input: interaction.Input, config: Config) Result {
    var output: Result = .{};
    const container_id = clay.ElementId.ID(config.id);
    if (config.semantic_registry) |registry| _ = registry.add(.{
        .element_id = container_id.id,
        .role = .group,
        .label = config.semantic_label,
        .disabled = config.disabled,
    });

    clay.UI()(.{
        .id = container_id,
        .layout = .{
            .sizing = .{ .w = .fixed(config.width), .h = .fit },
            .child_gap = theme.controls.gap_tiny,
            .direction = .top_to_bottom,
        },
        .background_color = theme.controls.scroll_surface,
        .corner_radius = .all(theme.controls.radius_medium),
    })({
        for (config.items, 0..) |item, index| {
            const id = headerId(config.id, index);
            const item_disabled = config.disabled or item.disabled;
            const expanded = isExpanded(config.expanded_mask, index);
            const focused = config.focused_id == id.id;
            const pointer = interaction.update(state, id.id, clay.pointerOver(id), input, item_disabled);
            if (config.semantic_registry) |registry| _ = registry.add(.{
                .element_id = id.id,
                .role = .button,
                .label = item.title,
                .disabled = item_disabled,
                .focused = focused,
                .expanded = expanded,
                .level = 1,
            });

            clay.UI()(.{
                .id = id,
                .layout = .{
                    .sizing = .{ .w = .fixed(config.width), .h = .fixed(44) },
                    .padding = .axes(14, 10),
                    .child_gap = theme.controls.gap_small,
                    .child_alignment = .{ .y = .center },
                },
                .background_color = if (item_disabled)
                    theme.controls.input_disabled
                else if (pointer.active)
                    theme.controls.accent_pressed
                else if (expanded)
                    theme.controls.surface_focused
                else if (pointer.hovered or focused)
                    theme.controls.surface_hover
                else
                    theme.controls.surface,
                .border = .{
                    .color = if (focused) theme.controls.focus else theme.controls.divider,
                    .width = if (focused)
                        .outside(theme.controls.focus_width)
                    else
                        .{ .bottom = 1 },
                },
            })({
                label.draw(if (expanded) "▾" else "▸", .{
                    .font_size = 15,
                    .color = if (item_disabled) theme.controls.text_disabled else theme.controls.text_muted,
                });
                label.draw(item.title, .{
                    .font_size = 15,
                    .color = if (item_disabled) theme.controls.text_disabled else theme.controls.text_secondary,
                });
            });

            if (pointer.clicked) {
                output.focus_index = index;
                output.expanded_mask = nextExpandedMask(config.expanded_mask, index, !expanded, config.mode);
            } else if (!item_disabled and focused) {
                if (input.activate_pressed) {
                    output.expanded_mask = nextExpandedMask(config.expanded_mask, index, !expanded, config.mode);
                } else if (input.right_pressed and !expanded) {
                    output.expanded_mask = nextExpandedMask(config.expanded_mask, index, true, config.mode);
                } else if (input.left_pressed and expanded) {
                    output.expanded_mask = nextExpandedMask(config.expanded_mask, index, false, config.mode);
                }
                if (input.home_pressed) {
                    output.focus_index = firstEnabled(config.items);
                } else if (input.end_pressed) {
                    output.focus_index = lastEnabled(config.items);
                } else if (input.up_pressed != input.down_pressed) {
                    output.focus_index = adjacentEnabled(
                        config.items,
                        index,
                        if (input.up_pressed) -1 else 1,
                    );
                }
            }

            if (expanded) {
                const id_panel = panelId(config.id, index);
                if (config.semantic_registry) |registry| _ = registry.add(.{
                    .element_id = id_panel.id,
                    .role = .group,
                    .label = item.title,
                    .disabled = item_disabled,
                    .level = 2,
                });
                clay.UI()(.{
                    .id = id_panel,
                    .layout = .{
                        .sizing = .{ .w = .fixed(config.width), .h = .fit },
                        .padding = .axes(16, 12),
                        .child_gap = theme.controls.gap_small,
                        .direction = .top_to_bottom,
                    },
                    .background_color = theme.controls.surface,
                    .border = .{ .color = theme.controls.divider, .width = .{ .bottom = 1 } },
                })({
                    if (config.draw_panel) |draw_panel| draw_panel(config.panel_context, index);
                });
            }
        }
    });
    return output;
}

pub fn headerId(accordion_id: []const u8, index: usize) clay.ElementId {
    return clay.ElementId.IDI(accordion_id, @intCast(index + 1));
}

pub fn panelId(accordion_id: []const u8, index: usize) clay.ElementId {
    return clay.ElementId.IDI(accordion_id, @intCast(0x1_0000 + index));
}

pub fn isExpanded(mask: u64, index: usize) bool {
    return index < 64 and mask & (@as(u64, 1) << @intCast(index)) != 0;
}

pub fn nextExpandedMask(mask: u64, index: usize, expanded: bool, mode: Mode) u64 {
    if (index >= 64) return mask;
    const bit = @as(u64, 1) << @intCast(index);
    if (!expanded) return mask & ~bit;
    return if (mode == .single) bit else mask | bit;
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

pub fn adjacentEnabled(items: []const Item, current: usize, direction: i8) ?usize {
    if (items.len == 0 or direction == 0) return null;
    var candidate = @min(current, items.len - 1);
    for (0..items.len) |_| {
        candidate = if (direction < 0)
            (if (candidate == 0) items.len - 1 else candidate - 1)
        else
            (candidate + 1) % items.len;
        if (!items[candidate].disabled) return candidate;
    }
    return null;
}

test "single accordion keeps at most one expanded panel" {
    try std.testing.expectEqual(@as(u64, 0b100), nextExpandedMask(0b011, 2, true, .single));
    try std.testing.expectEqual(@as(u64, 0), nextExpandedMask(0b100, 2, false, .single));
}

test "multiple accordion preserves unrelated panels" {
    try std.testing.expectEqual(@as(u64, 0b101), nextExpandedMask(0b001, 2, true, .multiple));
    try std.testing.expectEqual(@as(u64, 0b001), nextExpandedMask(0b101, 2, false, .multiple));
}

test "accordion navigation skips disabled headers and wraps" {
    const items = [_]Item{
        .{ .title = "Account" },
        .{ .title = "Disabled", .disabled = true },
        .{ .title = "About" },
    };
    try std.testing.expectEqual(@as(?usize, 2), adjacentEnabled(&items, 0, 1));
    try std.testing.expectEqual(@as(?usize, 0), adjacentEnabled(&items, 2, 1));
    try std.testing.expectEqual(@as(?usize, 2), lastEnabled(&items));
}

test "accordion ids separate headers panels and container" {
    try std.testing.expect(clay.ElementId.ID("SettingsAccordion").id != headerId("SettingsAccordion", 0).id);
    try std.testing.expect(headerId("SettingsAccordion", 0).id != panelId("SettingsAccordion", 0).id);
}
