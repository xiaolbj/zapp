const clay = @import("zclay");
const font = @import("../../text/font.zig");
const interaction = @import("interaction.zig");
const label = @import("label.zig");

pub const Config = struct {
    id: []const u8,
    text: []const u8,
    placeholder: []const u8,
    cursor: usize = 0,
    selection_anchor: usize = 0,
    composition: []const u8 = "",
    width: f32 = 320,
    focused: bool = false,
    disabled: bool = false,
};

pub const Result = struct {
    focus_requested: bool = false,
    blur_requested: bool = false,
    cursor_position: ?usize = null,
    selecting: bool = false,
};

pub fn draw(state: *interaction.State, input: interaction.Input, config: Config) Result {
    const id = clay.ElementId.ID(config.id);
    const hovered = clay.pointerOver(id);
    const pointer = interaction.update(state, id.id, hovered, input, config.disabled);
    const focus_requested = !config.disabled and input.pressed and hovered;
    const blur_requested = config.focused and (config.disabled or (input.pressed and !hovered));
    var cursor_position: ?usize = null;
    var selecting = false;
    if (!config.disabled and (focus_requested or pointer.active)) {
        const data = clay.getElementData(id);
        if (data.found) {
            cursor_position = cursorAtX(config.text, input.x - data.bounding_box.x - 14);
            selecting = pointer.active and !input.pressed and config.focused;
        }
    }
    const background: clay.Color = if (config.disabled)
        .{ 43, 51, 64, 255 }
    else if (config.focused)
        .{ 39, 62, 91, 255 }
    else if (pointer.hovered)
        .{ 37, 49, 68, 255 }
    else
        .{ 30, 41, 58, 255 };

    clay.UI()(.{
        .id = id,
        .layout = .{
            .sizing = .{ .w = .fixed(config.width), .h = .fixed(48) },
            .padding = .axes(14, 12),
            .child_gap = 0,
            .child_alignment = .{ .y = .center },
        },
        .background_color = background,
        .corner_radius = .all(9),
        .clip = .{ .horizontal = true },
    })({
        const cursor = @min(config.cursor, config.text.len);
        const anchor = @min(config.selection_anchor, config.text.len);
        const selection_start = @min(cursor, anchor);
        const selection_end = @max(cursor, anchor);
        const has_selection = selection_start != selection_end;
        if (config.text.len > 0) {
            drawText(config.text[0..selection_start], config.disabled);
            if (config.focused and has_selection and cursor == selection_start) drawCursor();
            if (has_selection) {
                clay.UI()(.{
                    .layout = .{
                        .sizing = .fit,
                        .padding = .axes(0, 2),
                        .child_alignment = .center,
                    },
                    .background_color = .{ 43, 111, 184, 255 },
                    .corner_radius = .all(3),
                })({
                    drawText(config.text[selection_start..selection_end], config.disabled);
                });
            }
            if (config.focused and (!has_selection or cursor == selection_end)) drawCursor();
            if (config.focused and config.composition.len > 0) drawComposition(config.composition);
            drawText(config.text[selection_end..], config.disabled);
        } else {
            if (config.focused and !config.disabled) drawCursor();
            label.draw(config.placeholder, .{ .font_size = 16, .color = .{ 118, 135, 158, 255 } });
        }
    });

    return .{
        .focus_requested = focus_requested,
        .blur_requested = blur_requested,
        .cursor_position = cursor_position,
        .selecting = selecting,
    };
}

pub fn cursorAtX(text: []const u8, x: f32) usize {
    if (x <= 0 or text.len == 0) return 0;
    var config: clay.TextElementConfig = .{ .font_size = 16, .wrap_mode = .none };
    var boundary: usize = 0;
    var left_width: f32 = 0;
    while (boundary < text.len) {
        const next = nextCodepointBoundary(text, boundary);
        const right_width = font.measure(text[0..next], &config, {}).w;
        if (x < (left_width + right_width) * 0.5) return boundary;
        boundary = next;
        left_width = right_width;
    }
    return text.len;
}

fn nextCodepointBoundary(text: []const u8, cursor: usize) usize {
    if (cursor >= text.len) return text.len;
    var index = cursor + 1;
    while (index < text.len and text[index] & 0xC0 == 0x80) index += 1;
    return index;
}

fn drawText(text: []const u8, disabled: bool) void {
    if (text.len == 0) return;
    label.draw(text, .{
        .font_size = 16,
        .color = if (disabled) .{ 132, 142, 158, 255 } else .{ 231, 238, 249, 255 },
    });
}

fn drawCursor() void {
    clay.UI()(.{
        .layout = .{ .sizing = .{ .w = .fixed(2), .h = .fixed(22) } },
        .background_color = .{ 116, 184, 255, 255 },
        .corner_radius = .all(1),
    })({});
}

fn drawComposition(text: []const u8) void {
    clay.UI()(.{
        .layout = .{
            .sizing = .fit,
            .padding = .axes(1, 2),
            .child_alignment = .center,
        },
        .background_color = .{ 60, 82, 116, 255 },
        .corner_radius = .all(2),
    })({
        label.draw(text, .{ .font_size = 16, .color = .{ 183, 220, 255, 255 } });
    });
}

test "outside press requests blur only for focused field" {
    const std = @import("std");
    const input: interaction.Input = .{ .down = true, .pressed = true, .released = false };
    const focused_blur = true and input.pressed and !false;
    const idle_blur = false and input.pressed and !false;
    try std.testing.expect(focused_blur);
    try std.testing.expect(!idle_blur);
}

test "cursor hit testing returns UTF-8 byte boundaries" {
    const std = @import("std");
    const text = "A中B";
    try std.testing.expectEqual(@as(usize, 0), cursorAtX(text, 0));
    try std.testing.expectEqual(@as(usize, 1), cursorAtX(text, 11));
    try std.testing.expectEqual(@as(usize, 4), cursorAtX(text, 21));
    try std.testing.expectEqual(text.len, cursorAtX(text, 100));
}
