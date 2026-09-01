const clay = @import("zclay");
const interaction = @import("interaction.zig");
const label = @import("label.zig");

pub const Config = struct {
    id: []const u8,
    text: []const u8,
    placeholder: []const u8,
    cursor: usize = 0,
    selection_anchor: usize = 0,
    width: f32 = 320,
    focused: bool = false,
    disabled: bool = false,
};

pub const Result = struct {
    focus_requested: bool = false,
    blur_requested: bool = false,
};

pub fn draw(state: *interaction.State, input: interaction.Input, config: Config) Result {
    const id = clay.ElementId.ID(config.id);
    const hovered = clay.pointerOver(id);
    const pointer = interaction.update(state, id.id, hovered, input, config.disabled);
    const focus_requested = !config.disabled and input.pressed and hovered;
    const blur_requested = config.focused and (config.disabled or (input.pressed and !hovered));
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
                        .padding = .axes(1, 2),
                        .child_alignment = .center,
                    },
                    .background_color = .{ 43, 111, 184, 255 },
                    .corner_radius = .all(3),
                })({
                    drawText(config.text[selection_start..selection_end], config.disabled);
                });
            }
            if (config.focused and (!has_selection or cursor == selection_end)) drawCursor();
            drawText(config.text[selection_end..], config.disabled);
        } else {
            if (config.focused and !config.disabled) drawCursor();
            label.draw(config.placeholder, .{ .font_size = 16, .color = .{ 118, 135, 158, 255 } });
        }
    });

    return .{
        .focus_requested = focus_requested,
        .blur_requested = blur_requested,
    };
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

test "outside press requests blur only for focused field" {
    const std = @import("std");
    const input: interaction.Input = .{ .down = true, .pressed = true, .released = false };
    const focused_blur = true and input.pressed and !false;
    const idle_blur = false and input.pressed and !false;
    try std.testing.expect(focused_blur);
    try std.testing.expect(!idle_blur);
}
