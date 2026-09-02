const clay = @import("zclay");
const interaction = @import("interaction.zig");
const label = @import("label.zig");
const semantics = @import("../semantics.zig");
const text_field = @import("text_field.zig");
const theme = @import("../theme.zig");

pub const Config = struct {
    id: []const u8,
    label_text: []const u8,
    text: []const u8,
    placeholder: []const u8,
    cursor: usize = 0,
    selection_anchor: usize = 0,
    composition: []const u8 = "",
    helper_text: []const u8 = "",
    error_message: []const u8 = "",
    width: f32 = 320,
    focused: bool = false,
    disabled: bool = false,
    required: bool = false,
    invalid: bool = false,
    semantic_registry: ?*semantics.Registry = null,
};

pub const Result = text_field.Result;

/// Composes a labelled single-line field while delegating all editing and IME
/// behavior to TextField. Validation state remains controlled by the caller.
pub fn draw(state: *interaction.State, input: interaction.Input, config: Config) Result {
    var result: Result = .{};
    clay.UI()(.{
        .id = containerId(config.id),
        .layout = .{
            .sizing = .{ .w = .fixed(config.width), .h = .fit },
            .child_gap = theme.controls.gap_small,
            .direction = .top_to_bottom,
        },
    })({
        clay.UI()(.{
            .layout = .{
                .sizing = .{ .w = .grow, .h = .fit },
                .child_gap = theme.controls.gap_tiny,
            },
        })({
            label.draw(config.label_text, .{
                .font_size = 15,
                .color = if (config.disabled) theme.controls.text_disabled else theme.controls.text_secondary,
            });
            if (config.required) label.draw("*", .{
                .font_size = 15,
                .color = if (config.disabled) theme.controls.text_disabled else theme.controls.error_color,
            });
        });

        result = text_field.draw(state, input, .{
            .id = config.id,
            .text = config.text,
            .placeholder = config.placeholder,
            .cursor = config.cursor,
            .selection_anchor = config.selection_anchor,
            .composition = config.composition,
            .width = config.width,
            .focused = config.focused,
            .disabled = config.disabled,
            .required = config.required,
            .invalid = config.invalid,
            .error_message = config.error_message,
            .semantic_label = config.label_text,
            .semantic_registry = config.semantic_registry,
        });

        const supporting_text = if (config.invalid and config.error_message.len > 0)
            config.error_message
        else
            config.helper_text;
        if (supporting_text.len > 0) label.draw(supporting_text, .{
            .font_size = 13,
            .color = if (config.invalid) theme.controls.error_color else theme.controls.text_muted,
            .semantic_id = supportingId(config.id),
            .semantic_role = if (config.invalid) .status else .text,
            .semantic_registry = config.semantic_registry,
        });
    });
    return result;
}

pub fn containerId(field_id: []const u8) clay.ElementId {
    return clay.ElementId.IDI(field_id, 0x10_000);
}

pub fn supportingId(field_id: []const u8) clay.ElementId {
    return clay.ElementId.IDI(field_id, 0x10_001);
}

test "form field ids do not collide with the editable field" {
    const std = @import("std");
    const field = clay.ElementId.ID("DemoTextField").id;
    try std.testing.expect(field != containerId("DemoTextField").id);
    try std.testing.expect(field != supportingId("DemoTextField").id);
    try std.testing.expect(containerId("DemoTextField").id != supportingId("DemoTextField").id);
}
