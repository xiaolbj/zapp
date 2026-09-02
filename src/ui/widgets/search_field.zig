const clay = @import("zclay");
const interaction = @import("interaction.zig");
const label = @import("label.zig");
const semantics = @import("../semantics.zig");
const text_field = @import("text_field.zig");
const theme = @import("../theme.zig");

pub const Config = struct {
    id: []const u8,
    text: []const u8,
    placeholder: []const u8 = "搜索",
    cursor: usize = 0,
    selection_anchor: usize = 0,
    composition: []const u8 = "",
    width: f32 = 320,
    focused: bool = false,
    clear_focused: bool = false,
    disabled: bool = false,
    semantic_label: []const u8 = "搜索",
    semantic_registry: ?*semantics.Registry = null,
};

pub const Result = struct {
    text: text_field.Result = .{},
    clear_requested: bool = false,
};

/// Controlled search input composed from TextField and an optional clear
/// action. The caller owns the text, editing target and focus arbitration.
pub fn draw(state: *interaction.State, input: interaction.Input, config: Config) Result {
    var result: Result = .{};
    const has_clear = config.text.len > 0;
    const clear_size: f32 = 48;
    const gap = if (has_clear) theme.controls.gap_small else 0;

    clay.UI()(.{
        .id = containerId(config.id),
        .layout = .{
            .sizing = .{ .w = .fixed(config.width), .h = .fixed(48) },
            .child_gap = gap,
            .child_alignment = .{ .y = .center },
        },
    })({
        result.text = text_field.draw(state, input, .{
            .id = config.id,
            .text = config.text,
            .placeholder = config.placeholder,
            .cursor = config.cursor,
            .selection_anchor = config.selection_anchor,
            .composition = config.composition,
            .width = config.width - if (has_clear) clear_size + gap else 0,
            .focused = config.focused,
            .disabled = config.disabled,
            .semantic_label = config.semantic_label,
            .semantic_registry = config.semantic_registry,
        });

        if (has_clear) {
            const id = clearId(config.id);
            if (config.semantic_registry) |registry| _ = registry.add(.{
                .element_id = id.id,
                .role = .button,
                .label = "清除搜索",
                .disabled = config.disabled,
                .focused = config.clear_focused,
            });
            const pointer = interaction.update(state, id.id, clay.pointerOver(id), input, config.disabled);
            const background: clay.Color = if (config.disabled)
                theme.controls.surface_disabled
            else if (pointer.active)
                theme.controls.accent_pressed
            else if (pointer.hovered or config.clear_focused)
                theme.controls.accent_hover
            else
                theme.controls.surface;
            clay.UI()(.{
                .id = id,
                .layout = .{
                    .sizing = .{ .w = .fixed(clear_size), .h = .fixed(clear_size) },
                    .child_alignment = .center,
                },
                .background_color = background,
                .corner_radius = .all(theme.controls.radius_medium),
                .border = .{
                    .color = theme.controls.focus,
                    .width = if (config.clear_focused) .outside(theme.controls.focus_width) else .{},
                },
            })({
                label.draw("×", .{
                    .font_size = 22,
                    .color = if (config.disabled) theme.controls.text_disabled else theme.controls.text_secondary,
                });
            });
            result.clear_requested = pointer.clicked or
                (config.clear_focused and input.activate_pressed and !config.disabled);
        }
    });
    return result;
}

pub fn containerId(field_id: []const u8) clay.ElementId {
    return clay.ElementId.IDI(field_id, 0x20_000);
}

pub fn clearId(field_id: []const u8) clay.ElementId {
    return clay.ElementId.IDI(field_id, 0x20_001);
}

test "search field auxiliary ids do not collide" {
    const std = @import("std");
    const field = clay.ElementId.ID("DemoSearchField").id;
    try std.testing.expect(field != containerId("DemoSearchField").id);
    try std.testing.expect(field != clearId("DemoSearchField").id);
    try std.testing.expect(containerId("DemoSearchField").id != clearId("DemoSearchField").id);
}
