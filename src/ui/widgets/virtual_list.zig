const std = @import("std");
const clay = @import("zclay");
const interaction = @import("interaction.zig");
const label = @import("label.zig");
const semantics = @import("../semantics.zig");
const theme = @import("../theme.zig");

pub const max_visible_rows = 32;
pub const max_label_bytes = 96;

pub const State = struct {
    labels: [max_visible_rows][max_label_bytes]u8 = undefined,
};

pub const FormatItemFn = *const fn (index: usize, buffer: []u8) []const u8;

pub const Config = struct {
    id: []const u8,
    item_count: usize,
    selected_index: usize,
    format_item: FormatItemFn,
    width: f32 = 320,
    height: f32 = 240,
    row_height: f32 = 42,
    padding: u16 = 8,
    overscan: usize = 2,
    disabled: bool = false,
    focused_id: ?u32 = null,
    semantic_label: []const u8 = "Virtual list",
    semantic_registry: ?*semantics.Registry = null,
};

pub const Result = struct {
    selected_index: ?usize = null,
    focus_index: ?usize = null,
    range: Range,
};

pub const Range = struct {
    start: usize,
    end: usize,

    pub fn len(self: Range) usize {
        return self.end - self.start;
    }
};

/// Draws only the visible rows plus a small overscan margin. Top and bottom
/// spacers preserve the full content height so Clay's native scrolling and
/// accessibility paging continue to operate on the complete logical list.
pub fn draw(
    widget_state: *State,
    interaction_state: *interaction.State,
    input: interaction.Input,
    config: Config,
) Result {
    const list_id = clay.ElementId.ID(config.id);
    const scroll = clay.getScrollContainerData(list_id);
    const scroll_y = if (scroll.found) scroll.scroll_position.y else 0;
    const range = visibleRange(
        config.item_count,
        config.row_height,
        config.height,
        config.padding,
        scroll_y,
        config.overscan,
    );
    const semantic_range = semanticRange(
        config.item_count,
        config.row_height,
        config.height,
        config.padding,
        scroll_y,
    );
    var output: Result = .{ .range = range };
    const selected_index = boundedIndex(config.selected_index, config.item_count);

    if (config.semantic_registry) |registry| _ = registry.add(.{
        .element_id = list_id.id,
        .role = .list,
        .label = config.semantic_label,
        .disabled = config.disabled,
        .scrollable = true,
    });
    const pushed_scroll_ancestor = if (config.semantic_registry) |registry|
        registry.pushScrollAncestor(list_id.id)
    else
        false;

    clay.UI()(.{
        .id = list_id,
        .layout = .{
            .sizing = .{ .w = .fixed(config.width), .h = .fixed(config.height) },
            .padding = .all(config.padding),
            .direction = .top_to_bottom,
        },
        .background_color = theme.controls.scroll_surface,
        .corner_radius = .all(theme.controls.radius_medium),
        .clip = .{ .vertical = true, .child_offset = clay.getScrollOffset() },
    })({
        const top_height = @as(f32, @floatFromInt(range.start)) * config.row_height;
        if (top_height > 0) spacer(config.id, std.math.maxInt(u32) - 1, top_height);

        for (range.start..range.end, 0..) |index, slot| {
            const id = itemId(config.id, index);
            const focused = config.focused_id == id.id;
            const selected = selected_index == index;
            const pointer = interaction.update(
                interaction_state,
                id.id,
                clay.pointerOver(id),
                input,
                config.disabled,
            );
            const item_label = config.format_item(index, &widget_state.labels[slot]);
            if (index >= semantic_range.start and index < semantic_range.end) {
                if (config.semantic_registry) |registry| _ = registry.add(.{
                    .element_id = id.id,
                    .role = .list_item,
                    .label = item_label,
                    .disabled = config.disabled,
                    .focused = focused,
                    .selected = selected,
                    .level = 1,
                });
            }

            clay.UI()(.{
                .id = id,
                .layout = .{
                    .sizing = .{ .w = .grow, .h = .fixed(config.row_height) },
                    .padding = .axes(14, 9),
                    .child_alignment = .{ .y = .center },
                },
                .background_color = if (config.disabled)
                    theme.controls.input_disabled
                else if (pointer.active)
                    theme.controls.accent_pressed
                else if (selected)
                    theme.controls.navigation_active
                else if (pointer.hovered or focused)
                    theme.controls.surface_hover
                else
                    theme.controls.surface,
                .border = .{
                    .color = theme.controls.focus,
                    .width = if (focused) .outside(theme.controls.focus_width) else .{},
                },
            })(label.draw(item_label, .{
                .font_size = 15,
                .color = if (config.disabled)
                    theme.controls.text_disabled
                else if (selected)
                    theme.controls.on_accent
                else
                    theme.controls.text_secondary,
            }));

            if (pointer.clicked) {
                output.selected_index = index;
                output.focus_index = index;
            } else if (!config.disabled and focused) {
                const target = navigationTarget(index, config.item_count, input);
                if (target) |target_index| {
                    output.selected_index = target_index;
                    output.focus_index = target_index;
                    ensureVisible(scroll, target_index, config);
                } else if (input.activate_pressed) {
                    output.selected_index = index;
                }
            }
        }

        const remaining = config.item_count - range.end;
        const bottom_height = @as(f32, @floatFromInt(remaining)) * config.row_height;
        if (bottom_height > 0) spacer(config.id, std.math.maxInt(u32) - 2, bottom_height);
    });
    if (pushed_scroll_ancestor) config.semantic_registry.?.popScrollAncestor();
    return output;
}

pub fn itemId(list_id: []const u8, index: usize) clay.ElementId {
    return clay.ElementId.IDI(list_id, @intCast(index + 1));
}

pub fn boundedIndex(index: usize, count: usize) ?usize {
    if (count == 0) return null;
    return @min(index, count - 1);
}

pub fn visibleRange(
    item_count: usize,
    row_height: f32,
    viewport_height: f32,
    padding: u16,
    scroll_y: f32,
    overscan: usize,
) Range {
    if (item_count == 0 or row_height <= 0 or viewport_height <= 0) return .{ .start = 0, .end = 0 };
    const padding_height: f32 = @floatFromInt(padding);
    const content_offset = @max(-scroll_y - padding_height, 0);
    const first_visible: usize = @intFromFloat(@floor(content_offset / row_height));
    const raw_start = first_visible -| overscan;
    const rows_in_view: usize = @intFromFloat(@ceil(viewport_height / row_height));
    const requested = @min(rows_in_view + overscan * 2 + 1, max_visible_rows);
    const window = @min(requested, item_count);
    const start = @min(raw_start, item_count - window);
    return .{ .start = start, .end = start + window };
}

pub fn semanticRange(
    item_count: usize,
    row_height: f32,
    viewport_height: f32,
    padding: u16,
    scroll_y: f32,
) Range {
    if (item_count == 0 or row_height <= 0 or viewport_height <= 0) return .{ .start = 0, .end = 0 };
    const padding_height: f32 = @floatFromInt(padding);
    const inner_height = @max(viewport_height - padding_height * 2, 0);
    const content_offset = @max(-scroll_y - padding_height, 0);
    const start = @min(@as(usize, @intFromFloat(@floor(content_offset / row_height))), item_count);
    const end = @min(@as(usize, @intFromFloat(@ceil((content_offset + inner_height) / row_height))), item_count);
    return .{ .start = start, .end = @max(end, start) };
}

fn navigationTarget(index: usize, count: usize, input: interaction.Input) ?usize {
    if (count == 0) return null;
    if (input.home_pressed) return 0;
    if (input.end_pressed) return count - 1;
    if (input.up_pressed != input.down_pressed) {
        if (input.up_pressed) return if (index == 0) 0 else index - 1;
        return @min(index + 1, count - 1);
    }
    return null;
}

fn ensureVisible(scroll: anytype, index: usize, config: Config) void {
    if (!scroll.found) return;
    const padding_height: f32 = @floatFromInt(config.padding);
    const row_top = padding_height + @as(f32, @floatFromInt(index)) * config.row_height;
    const row_bottom = row_top + config.row_height;
    const current_offset = -scroll.scroll_position.y;
    var target_offset = current_offset;
    if (row_top < current_offset) {
        target_offset = row_top;
    } else if (row_bottom > current_offset + config.height) {
        target_offset = row_bottom - config.height;
    }
    const content_height = padding_height * 2 + @as(f32, @floatFromInt(config.item_count)) * config.row_height;
    const max_offset = @max(content_height - config.height, 0);
    scroll.scroll_position.y = -@min(@max(target_offset, 0), max_offset);
}

fn spacer(list_id: []const u8, suffix: u32, height: f32) void {
    clay.UI()(.{
        .id = clay.ElementId.IDI(list_id, suffix),
        .layout = .{ .sizing = .{ .w = .grow, .h = .fixed(height) } },
    })({});
}

test "visible range stays bounded for a thousand-row list" {
    const range = visibleRange(1000, 42, 240, 8, -4200, 2);
    try std.testing.expect(range.start >= 97);
    try std.testing.expect(range.end <= 108);
    try std.testing.expect(range.len() < 16);
}

test "visible range clamps at both ends" {
    const first = visibleRange(5, 40, 120, 8, 0, 2);
    const last = visibleRange(5, 40, 120, 8, -1000, 2);
    try std.testing.expectEqual(@as(usize, 0), first.start);
    try std.testing.expectEqual(@as(usize, 5), first.end);
    try std.testing.expectEqual(@as(usize, 0), last.start);
    try std.testing.expectEqual(@as(usize, 5), last.end);
}

test "semantic range excludes overscan rows outside the clip" {
    const first = semanticRange(1000, 42, 240, 8, 0);
    const scrolled = semanticRange(1000, 42, 240, 8, -192);
    try std.testing.expectEqual(@as(Range, .{ .start = 0, .end = 6 }), first);
    try std.testing.expectEqual(@as(Range, .{ .start = 4, .end = 10 }), scrolled);
}

test "virtual list ids remain stable across ranges" {
    try std.testing.expect(itemId("RecordsList", 7).id != itemId("RecordsList", 8).id);
    try std.testing.expect(itemId("RecordsList", 7).id == itemId("RecordsList", 7).id);
}
