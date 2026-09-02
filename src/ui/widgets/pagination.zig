const std = @import("std");
const clay = @import("zclay");
const interaction = @import("interaction.zig");
const label = @import("label.zig");
const semantics = @import("../semantics.zig");
const theme = @import("../theme.zig");

pub const max_tokens = 7;

pub const Token = union(enum) {
    page: usize,
    gap,
};

pub const Layout = struct {
    tokens: [max_tokens]Token = undefined,
    count: usize = 0,

    pub fn items(self: *const Layout) []const Token {
        return self.tokens[0..self.count];
    }
};

pub const State = struct {
    status_text: [96]u8 = undefined,
    page_text: [max_tokens][24]u8 = undefined,
    semantic_text: [max_tokens][48]u8 = undefined,
};

pub const Config = struct {
    id: []const u8,
    total_items: usize,
    page_size: usize,
    current_page: usize,
    disabled: bool = false,
    focused_id: ?u32 = null,
    semantic_label: []const u8 = "Pagination",
    semantic_registry: ?*semantics.Registry = null,
};

pub const Result = struct {
    selected_page: ?usize = null,
    focus_id: ?u32 = null,
};

/// Draws a controlled pagination bar. The page window always preserves the
/// first and last page and inserts gaps when the total cannot fit compactly.
pub fn draw(
    widget_state: *State,
    interaction_state: *interaction.State,
    input: interaction.Input,
    config: Config,
) Result {
    var output: Result = .{};
    const count = pageCount(config.total_items, config.page_size);
    const current = boundedPage(config.current_page, count);
    const layout = pageLayout(count, current);
    const container_id = clay.ElementId.ID(config.id);
    const status_text = std.fmt.bufPrint(
        &widget_state.status_text,
        "第 {d} 页，共 {d} 页",
        .{ current + 1, count },
    ) catch "分页状态不可用";

    if (config.semantic_registry) |registry| _ = registry.add(.{
        .element_id = container_id.id,
        .role = .navigation,
        .label = config.semantic_label,
        .value_text = status_text,
        .disabled = config.disabled,
    });

    clay.UI()(.{
        .id = container_id,
        .layout = .{
            .sizing = .fit,
            .child_gap = 6,
            .direction = .left_to_right,
            .child_alignment = .{ .y = .center },
        },
    })({
        drawPageButton(
            interaction_state,
            input,
            config,
            previousId(config.id),
            "‹",
            "上一页",
            if (current > 0) current - 1 else 0,
            current,
            count,
            config.disabled or current == 0,
            false,
            42,
            &output,
        );

        for (layout.items(), 0..) |token, token_index| {
            switch (token) {
                .gap => clay.UI()(.{
                    .id = gapId(config.id, token_index),
                    .layout = .{
                        .sizing = .{ .w = .fixed(28), .h = .fixed(38) },
                        .child_alignment = .center,
                    },
                })(label.draw("…", .{ .font_size = 15, .color = theme.controls.text_muted })),
                .page => |page_index| {
                    const page_text = std.fmt.bufPrint(
                        &widget_state.page_text[token_index],
                        "{d}",
                        .{page_index + 1},
                    ) catch "?";
                    const semantic_text = std.fmt.bufPrint(
                        &widget_state.semantic_text[token_index],
                        "第 {d} 页",
                        .{page_index + 1},
                    ) catch "页码";
                    drawPageButton(
                        interaction_state,
                        input,
                        config,
                        pageId(config.id, page_index),
                        page_text,
                        semantic_text,
                        page_index,
                        current,
                        count,
                        config.disabled,
                        page_index == current,
                        38,
                        &output,
                    );
                },
            }
        }

        drawPageButton(
            interaction_state,
            input,
            config,
            nextId(config.id),
            "›",
            "下一页",
            if (current + 1 < count) current + 1 else current,
            current,
            count,
            config.disabled or current + 1 >= count,
            false,
            42,
            &output,
        );
    });
    return output;
}

fn drawPageButton(
    interaction_state: *interaction.State,
    input: interaction.Input,
    config: Config,
    id: clay.ElementId,
    text: []const u8,
    semantic_label: []const u8,
    target_page: usize,
    current_page: usize,
    page_count: usize,
    disabled: bool,
    selected: bool,
    width: f32,
    output: *Result,
) void {
    const focused = config.focused_id == id.id;
    const pointer = interaction.update(interaction_state, id.id, clay.pointerOver(id), input, disabled);
    if (config.semantic_registry) |registry| _ = registry.add(.{
        .element_id = id.id,
        .role = .button,
        .label = semantic_label,
        .disabled = disabled,
        .focused = focused,
        .selected = selected,
    });

    clay.UI()(.{
        .id = id,
        .layout = .{
            .sizing = .{ .w = .fixed(width), .h = .fixed(38) },
            .child_alignment = .center,
        },
        .background_color = if (disabled)
            theme.controls.input_disabled
        else if (pointer.active)
            theme.controls.accent_pressed
        else if (selected)
            theme.controls.navigation_active
        else if (pointer.hovered or focused)
            theme.controls.surface_hover
        else
            theme.controls.surface,
        .corner_radius = .all(theme.controls.radius_small),
        .border = .{
            .color = theme.controls.focus,
            .width = if (focused) .outside(theme.controls.focus_width) else .{},
        },
    })(label.draw(text, .{
        .font_size = 14,
        .color = if (disabled)
            theme.controls.text_disabled
        else if (selected)
            theme.controls.on_accent
        else
            theme.controls.text_secondary,
    }));

    if (pointer.clicked) {
        output.focus_id = pageId(config.id, target_page).id;
        if (target_page != current_page) output.selected_page = target_page;
    } else if (!disabled and focused) {
        if (input.activate_pressed and target_page != current_page) output.selected_page = target_page;
        if (navigationTarget(current_page, page_count, input)) |navigation_page| {
            output.focus_id = pageId(config.id, navigation_page).id;
            if (navigation_page != current_page) output.selected_page = navigation_page;
        }
    }
}

pub fn pageCount(total_items: usize, page_size: usize) usize {
    if (page_size == 0 or total_items == 0) return 1;
    return 1 + (total_items - 1) / page_size;
}

pub fn boundedPage(page: usize, count: usize) usize {
    if (count == 0) return 0;
    return @min(page, count - 1);
}

pub fn pageLayout(count: usize, current_page: usize) Layout {
    const total = @max(count, 1);
    const current = boundedPage(current_page, total);
    var layout: Layout = .{};
    if (total <= max_tokens) {
        for (0..total) |page| appendToken(&layout, .{ .page = page });
        return layout;
    }
    if (current <= 3) {
        for (0..5) |page| appendToken(&layout, .{ .page = page });
        appendToken(&layout, .gap);
        appendToken(&layout, .{ .page = total - 1 });
    } else if (current >= total - 4) {
        appendToken(&layout, .{ .page = 0 });
        appendToken(&layout, .gap);
        for (total - 5..total) |page| appendToken(&layout, .{ .page = page });
    } else {
        appendToken(&layout, .{ .page = 0 });
        appendToken(&layout, .gap);
        appendToken(&layout, .{ .page = current - 1 });
        appendToken(&layout, .{ .page = current });
        appendToken(&layout, .{ .page = current + 1 });
        appendToken(&layout, .gap);
        appendToken(&layout, .{ .page = total - 1 });
    }
    return layout;
}

pub fn previousId(pagination_id: []const u8) clay.ElementId {
    return clay.ElementId.IDI(pagination_id, std.math.maxInt(u32) - 1);
}

pub fn nextId(pagination_id: []const u8) clay.ElementId {
    return clay.ElementId.IDI(pagination_id, std.math.maxInt(u32));
}

pub fn pageId(pagination_id: []const u8, page_index: usize) clay.ElementId {
    return clay.ElementId.IDI(pagination_id, @intCast(page_index + 1));
}

fn gapId(pagination_id: []const u8, token_index: usize) clay.ElementId {
    return clay.ElementId.IDI(pagination_id, @intCast(0xff00_0000 + token_index));
}

fn appendToken(layout: *Layout, token: Token) void {
    if (layout.count == layout.tokens.len) return;
    layout.tokens[layout.count] = token;
    layout.count += 1;
}

fn navigationTarget(current: usize, count: usize, input: interaction.Input) ?usize {
    if (count == 0) return null;
    if (input.home_pressed) return 0;
    if (input.end_pressed) return count - 1;
    if (input.left_pressed and current > 0) return current - 1;
    if (input.right_pressed and current + 1 < count) return current + 1;
    return null;
}

test "page count handles empty exact and partial pages" {
    try std.testing.expectEqual(@as(usize, 1), pageCount(0, 20));
    try std.testing.expectEqual(@as(usize, 1), pageCount(20, 20));
    try std.testing.expectEqual(@as(usize, 2), pageCount(21, 20));
    try std.testing.expectEqual(@as(usize, 1), pageCount(20, 0));
}

test "small pagination emits every page" {
    const layout = pageLayout(4, 2);
    try std.testing.expectEqual(@as(usize, 4), layout.count);
    try std.testing.expectEqual(@as(usize, 0), layout.tokens[0].page);
    try std.testing.expectEqual(@as(usize, 3), layout.tokens[3].page);
}

test "large pagination preserves boundaries and gaps" {
    const start = pageLayout(20, 1);
    try std.testing.expectEqual(@as(usize, 0), start.tokens[0].page);
    try std.testing.expect(start.tokens[5] == .gap);
    try std.testing.expectEqual(@as(usize, 19), start.tokens[6].page);

    const middle = pageLayout(20, 10);
    try std.testing.expectEqual(@as(usize, 0), middle.tokens[0].page);
    try std.testing.expect(middle.tokens[1] == .gap);
    try std.testing.expectEqual(@as(usize, 10), middle.tokens[3].page);
    try std.testing.expect(middle.tokens[5] == .gap);
    try std.testing.expectEqual(@as(usize, 19), middle.tokens[6].page);

    const end = pageLayout(20, 19);
    try std.testing.expectEqual(@as(usize, 0), end.tokens[0].page);
    try std.testing.expect(end.tokens[1] == .gap);
    try std.testing.expectEqual(@as(usize, 19), end.tokens[6].page);
}

test "pagination ids remain stable and separate" {
    try std.testing.expect(pageId("RecordsPages", 2).id == pageId("RecordsPages", 2).id);
    try std.testing.expect(pageId("RecordsPages", 0).id != previousId("RecordsPages").id);
    try std.testing.expect(previousId("RecordsPages").id != nextId("RecordsPages").id);
}
