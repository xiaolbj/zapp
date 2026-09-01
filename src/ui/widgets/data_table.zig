const std = @import("std");
const clay = @import("zclay");
const interaction = @import("interaction.zig");
const label = @import("label.zig");
const semantics = @import("../semantics.zig");
const theme = @import("../theme.zig");

pub const max_columns = 6;
pub const max_rows = 24;
pub const max_cell_bytes = 96;
pub const max_row_label_bytes = 384;

pub const SortDirection = enum {
    ascending,
    descending,

    pub fn toggled(self: SortDirection) SortDirection {
        return if (self == .ascending) .descending else .ascending;
    }
};

pub const Column = struct {
    label: []const u8,
    width: f32,
    sortable: bool = true,
};

pub const SortRequest = struct {
    column_index: usize,
    direction: SortDirection,
};

pub const State = struct {
    cell_labels: [max_rows][max_columns][max_cell_bytes]u8 = undefined,
    cell_lengths: [max_rows][max_columns]usize = @splat(@splat(0)),
    row_labels: [max_rows][max_row_label_bytes]u8 = undefined,
    position_labels: [max_rows][64]u8 = undefined,
};

pub const FormatCellFn = *const fn (row_index: usize, column_index: usize, buffer: []u8) []const u8;

pub const Config = struct {
    id: []const u8,
    columns: []const Column,
    row_count: usize,
    /// Optional display-order to stable-row-index mapping. When absent or the
    /// wrong length, rows retain their natural order.
    row_order: []const usize = &.{},
    selected_row_index: usize,
    sort_column_index: usize,
    sort_direction: SortDirection,
    format_cell: FormatCellFn,
    width: f32,
    row_height: f32 = 42,
    header_height: f32 = 44,
    disabled: bool = false,
    focused_id: ?u32 = null,
    semantic_label: []const u8 = "Data table",
    semantic_registry: ?*semantics.Registry = null,
};

pub const Result = struct {
    selected_row_index: ?usize = null,
    sort_request: ?SortRequest = null,
    focus_id: ?u32 = null,
};

/// Draws a controlled, fixed-size data table. The caller owns stable row
/// identity, ordering and sort state; the widget only reports user intent.
pub fn draw(
    widget_state: *State,
    interaction_state: *interaction.State,
    input: interaction.Input,
    config: Config,
) Result {
    var output: Result = .{};
    const column_count = @min(config.columns.len, max_columns);
    const row_count = @min(config.row_count, max_rows);
    const table_id = clay.ElementId.ID(config.id);
    const selected_display_index = displayIndexOf(config, row_count, config.selected_row_index) orelse 0;

    if (config.semantic_registry) |registry| _ = registry.add(.{
        .element_id = table_id.id,
        .role = .table,
        .label = config.semantic_label,
        .disabled = config.disabled,
        .row_count = @intCast(row_count + 1),
        .column_count = @intCast(column_count),
    });

    clay.UI()(.{
        .id = table_id,
        .layout = .{
            .sizing = .{ .w = .fixed(config.width), .h = .fit },
            .direction = .top_to_bottom,
        },
        .background_color = theme.controls.scroll_surface,
        .corner_radius = .all(theme.controls.radius_medium),
        .clip = .{ .horizontal = true },
    })({
        clay.UI()(.{
            .id = clay.ElementId.IDI(config.id, std.math.maxInt(u32)),
            .layout = .{
                .sizing = .{ .w = .fixed(config.width), .h = .fixed(config.header_height) },
                .direction = .left_to_right,
            },
            .background_color = theme.controls.surface_muted,
        })({
            for (config.columns[0..column_count], 0..) |column, column_index| {
                drawHeader(
                    interaction_state,
                    input,
                    config,
                    column,
                    column_index,
                    row_count,
                    selected_display_index,
                    &output,
                );
            }
        });

        for (0..row_count) |display_index| {
            const stable_index = stableRowIndex(config, display_index);
            drawRow(
                widget_state,
                interaction_state,
                input,
                config,
                column_count,
                row_count,
                display_index,
                stable_index,
                &output,
            );
        }
    });
    return output;
}

fn drawHeader(
    interaction_state: *interaction.State,
    input: interaction.Input,
    config: Config,
    column: Column,
    column_index: usize,
    row_count: usize,
    selected_display_index: usize,
    output: *Result,
) void {
    const id = headerId(config.id, column_index);
    const focused = config.focused_id == id.id;
    const active_sort_column = boundedSortColumn(config.columns.len, config.sort_column_index);
    const sorted = active_sort_column == column_index;
    const pointer = interaction.update(
        interaction_state,
        id.id,
        clay.pointerOver(id),
        input,
        config.disabled or !column.sortable,
    );
    const direction_label = if (!sorted)
        ""
    else if (config.sort_direction == .ascending)
        "升序"
    else
        "降序";
    if (config.semantic_registry) |registry| _ = registry.add(.{
        .element_id = id.id,
        .role = .column_header,
        .label = column.label,
        .value_text = direction_label,
        .disabled = config.disabled or !column.sortable,
        .focused = focused,
        .row_index = 0,
        .column_index = @intCast(column_index),
    });

    clay.UI()(.{
        .id = id,
        .layout = .{
            .sizing = .{ .w = .fixed(column.width), .h = .fixed(config.header_height) },
            .padding = .axes(12, 9),
            .child_gap = theme.controls.gap_small,
            .child_alignment = .{ .y = .center },
        },
        .background_color = if (pointer.active)
            theme.controls.accent_pressed
        else if (pointer.hovered or focused)
            theme.controls.surface_focused
        else
            theme.controls.surface_muted,
        .border = .{
            .color = if (focused) theme.controls.focus else theme.controls.divider,
            .width = if (focused)
                .outside(theme.controls.focus_width)
            else
                .{ .right = 1, .bottom = 1 },
        },
    })({
        label.draw(column.label, .{
            .font_size = 14,
            .color = if (config.disabled or !column.sortable) theme.controls.text_disabled else theme.controls.text,
        });
        if (sorted) label.draw(if (config.sort_direction == .ascending) "↑" else "↓", .{
            .font_size = 14,
            .color = theme.controls.focus,
        });
    });

    if (pointer.clicked) {
        output.focus_id = id.id;
        output.sort_request = sortRequest(active_sort_column, config.sort_direction, column_index);
    } else if (!config.disabled and column.sortable and focused) {
        if (input.activate_pressed) {
            output.sort_request = sortRequest(active_sort_column, config.sort_direction, column_index);
        }
        if (input.home_pressed) {
            output.focus_id = headerId(config.id, firstSortableColumn(config.columns)).id;
        } else if (input.end_pressed) {
            output.focus_id = headerId(config.id, lastSortableColumn(config.columns)).id;
        } else if (input.left_pressed != input.right_pressed) {
            const direction: i8 = if (input.left_pressed) -1 else 1;
            const target = adjacentSortableColumn(config.columns, column_index, direction);
            output.focus_id = headerId(config.id, target).id;
        } else if (input.down_pressed and row_count > 0) {
            output.focus_id = rowId(config.id, stableRowIndex(config, selected_display_index)).id;
        }
    }
}

fn drawRow(
    widget_state: *State,
    interaction_state: *interaction.State,
    input: interaction.Input,
    config: Config,
    column_count: usize,
    row_count: usize,
    display_index: usize,
    stable_index: usize,
    output: *Result,
) void {
    const id = rowId(config.id, stable_index);
    const focused = config.focused_id == id.id;
    const selected = config.selected_row_index == stable_index;
    const pointer = interaction.update(interaction_state, id.id, clay.pointerOver(id), input, config.disabled);
    var row_label_length: usize = 0;
    for (config.columns[0..column_count], 0..) |_, column_index| {
        const cell_text = config.format_cell(
            stable_index,
            column_index,
            &widget_state.cell_labels[display_index][column_index],
        );
        widget_state.cell_lengths[display_index][column_index] = @min(
            cell_text.len,
            widget_state.cell_labels[display_index][column_index].len,
        );
        if (column_index > 0) appendText(&widget_state.row_labels[display_index], &row_label_length, "，");
        appendText(&widget_state.row_labels[display_index], &row_label_length, cell_text);
    }
    const position_text = std.fmt.bufPrint(
        &widget_state.position_labels[display_index],
        "第 {d} 行，共 {d} 行",
        .{ display_index + 1, row_count },
    ) catch "";
    if (config.semantic_registry) |registry| _ = registry.add(.{
        .element_id = id.id,
        .role = .row,
        .label = widget_state.row_labels[display_index][0..row_label_length],
        .value_text = position_text,
        .disabled = config.disabled,
        .focused = focused,
        .selected = selected,
        .row_index = @intCast(display_index + 1),
        .column_index = 0,
        .column_span = @intCast(@max(column_count, 1)),
    });

    clay.UI()(.{
        .id = id,
        .layout = .{
            .sizing = .{ .w = .fixed(config.width), .h = .fixed(config.row_height) },
            .direction = .left_to_right,
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
            .color = if (focused) theme.controls.focus else theme.controls.divider,
            .width = if (focused) .outside(theme.controls.focus_width) else .{ .bottom = 1 },
        },
    })({
        for (config.columns[0..column_count], 0..) |column, column_index| {
            clay.UI()(.{
                .layout = .{
                    .sizing = .{ .w = .fixed(column.width), .h = .fixed(config.row_height) },
                    .padding = .axes(12, 9),
                    .child_alignment = .{ .y = .center },
                },
                .border = .{ .color = theme.controls.divider, .width = .{ .right = 1 } },
            })(label.draw(widget_state.cell_labels[display_index][column_index][0..widget_state.cell_lengths[display_index][column_index]], .{
                .font_size = 14,
                .color = if (config.disabled)
                    theme.controls.text_disabled
                else if (selected)
                    theme.controls.on_accent
                else
                    theme.controls.text_secondary,
            }));
        }
    });

    if (pointer.clicked) {
        output.focus_id = id.id;
        output.selected_row_index = stable_index;
    } else if (!config.disabled and focused) {
        if (input.activate_pressed) output.selected_row_index = stable_index;
        if (rowNavigationTarget(display_index, row_count, input)) |target_display| {
            const target_stable = stableRowIndex(config, target_display);
            output.focus_id = rowId(config.id, target_stable).id;
            output.selected_row_index = target_stable;
        } else if (input.up_pressed and display_index == 0 and config.columns.len > 0) {
            output.focus_id = headerId(config.id, boundedSortColumn(config.columns.len, config.sort_column_index)).id;
        }
    }
}

pub fn headerId(table_id: []const u8, column_index: usize) clay.ElementId {
    return clay.ElementId.IDI(table_id, @intCast(column_index + 1));
}

pub fn rowId(table_id: []const u8, stable_row_index: usize) clay.ElementId {
    return clay.ElementId.IDI(table_id, @intCast(0x1_0000 + stable_row_index));
}

pub fn sortRequest(current_column: usize, current_direction: SortDirection, requested_column: usize) SortRequest {
    return .{
        .column_index = requested_column,
        .direction = if (current_column == requested_column) current_direction.toggled() else .ascending,
    };
}

fn boundedSortColumn(column_count: usize, column_index: usize) usize {
    const rendered_count = @min(column_count, max_columns);
    if (rendered_count == 0) return 0;
    return @min(column_index, rendered_count - 1);
}

fn stableRowIndex(config: Config, display_index: usize) usize {
    if (config.row_order.len == config.row_count and display_index < config.row_order.len) {
        return config.row_order[display_index];
    }
    return display_index;
}

fn displayIndexOf(config: Config, row_count: usize, stable_index: usize) ?usize {
    for (0..row_count) |display_index| {
        if (stableRowIndex(config, display_index) == stable_index) return display_index;
    }
    return null;
}

fn rowNavigationTarget(index: usize, count: usize, input: interaction.Input) ?usize {
    if (count == 0) return null;
    if (input.home_pressed) return 0;
    if (input.end_pressed) return count - 1;
    if (input.down_pressed and index + 1 < count) return index + 1;
    if (input.up_pressed and index > 0) return index - 1;
    return null;
}

fn firstSortableColumn(columns: []const Column) usize {
    for (columns, 0..) |column, index| if (column.sortable) return index;
    return 0;
}

fn lastSortableColumn(columns: []const Column) usize {
    var index = columns.len;
    while (index > 0) {
        index -= 1;
        if (columns[index].sortable) return index;
    }
    return 0;
}

fn adjacentSortableColumn(columns: []const Column, current: usize, direction: i8) usize {
    if (columns.len == 0 or direction == 0) return 0;
    var candidate = @min(current, columns.len - 1);
    for (0..columns.len) |_| {
        candidate = if (direction < 0)
            (if (candidate == 0) columns.len - 1 else candidate - 1)
        else
            (candidate + 1) % columns.len;
        if (columns[candidate].sortable) return candidate;
    }
    return @min(current, columns.len - 1);
}

fn appendText(buffer: []u8, length: *usize, text: []const u8) void {
    const remaining = buffer.len - @min(length.*, buffer.len);
    var amount = @min(remaining, text.len);
    while (amount > 0 and amount < text.len and text[amount] & 0xc0 == 0x80) amount -= 1;
    @memcpy(buffer[length.*..][0..amount], text[0..amount]);
    length.* += amount;
}

test "table ids separate container headers and stable rows" {
    try std.testing.expect(clay.ElementId.ID("RecordsTable").id != headerId("RecordsTable", 0).id);
    try std.testing.expect(headerId("RecordsTable", 0).id != rowId("RecordsTable", 0).id);
    try std.testing.expect(rowId("RecordsTable", 7).id == rowId("RecordsTable", 7).id);
}

test "sort request toggles only the current column" {
    try std.testing.expectEqual(
        SortRequest{ .column_index = 1, .direction = .descending },
        sortRequest(1, .ascending, 1),
    );
    try std.testing.expectEqual(
        SortRequest{ .column_index = 2, .direction = .ascending },
        sortRequest(1, .descending, 2),
    );
}

test "sort column remains inside the rendered column limit" {
    try std.testing.expectEqual(@as(usize, 0), boundedSortColumn(0, 8));
    try std.testing.expectEqual(@as(usize, 2), boundedSortColumn(3, 8));
    try std.testing.expectEqual(max_columns - 1, boundedSortColumn(max_columns + 4, 99));
}

test "row navigation clamps and supports first and last" {
    try std.testing.expectEqual(@as(?usize, 3), rowNavigationTarget(2, 5, .{
        .down = false,
        .pressed = false,
        .released = false,
        .down_pressed = true,
    }));
    try std.testing.expectEqual(@as(?usize, null), rowNavigationTarget(4, 5, .{
        .down = false,
        .pressed = false,
        .released = false,
        .down_pressed = true,
    }));
    try std.testing.expectEqual(@as(?usize, 0), rowNavigationTarget(3, 5, .{
        .down = false,
        .pressed = false,
        .released = false,
        .home_pressed = true,
    }));
}

test "sortable column navigation skips disabled headers" {
    const columns = [_]Column{
        .{ .label = "ID", .width = 80 },
        .{ .label = "Action", .width = 100, .sortable = false },
        .{ .label = "Status", .width = 120 },
    };
    try std.testing.expectEqual(@as(usize, 2), adjacentSortableColumn(&columns, 0, 1));
    try std.testing.expectEqual(@as(usize, 0), adjacentSortableColumn(&columns, 2, -1));
}

test "semantic row labels truncate only at UTF-8 boundaries" {
    var buffer: [5]u8 = undefined;
    var length: usize = 0;
    appendText(&buffer, &length, "中文");
    try std.testing.expectEqual(@as(usize, 3), length);
    try std.testing.expectEqualStrings("中", buffer[0..length]);
}
