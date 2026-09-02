const std = @import("std");
const clay = @import("zclay");
const interaction = @import("interaction.zig");
const label = @import("label.zig");
const semantics = @import("../semantics.zig");
const theme = @import("../theme.zig");

pub const State = struct {
    value_text: [32]u8 = undefined,
};

pub const Config = struct {
    id: []const u8,
    value: i32,
    min: i32,
    max: i32,
    step: i32 = 1,
    width: f32 = 260,
    disabled: bool = false,
    focused: bool = false,
    semantic_label: []const u8 = "Number",
    semantic_registry: ?*semantics.Registry = null,
};

/// Draws a controlled integer stepper. Pointer and keyboard interaction only
/// report a requested value; the caller owns the authoritative state.
pub fn draw(
    state: *State,
    interaction_state: *interaction.State,
    input: interaction.Input,
    config: Config,
) ?i32 {
    const bounds = normalizedBounds(config.min, config.max);
    const value = clampValue(config.value, bounds.min, bounds.max);
    const width = @max(config.width, theme.controls.control_height * 2 + 40);
    const value_text = std.fmt.bufPrint(&state.value_text, "{d}", .{value}) catch "?";
    const id = clay.ElementId.ID(config.id);
    const decrement_id = decrementId(config.id);
    const increment_id = incrementId(config.id);
    const decrement_disabled = config.disabled or value <= bounds.min;
    const increment_disabled = config.disabled or value >= bounds.max;
    const decrement_interaction = interaction.update(
        interaction_state,
        decrement_id.id,
        clay.pointerOver(decrement_id),
        input,
        decrement_disabled,
    );
    const increment_interaction = interaction.update(
        interaction_state,
        increment_id.id,
        clay.pointerOver(increment_id),
        input,
        increment_disabled,
    );

    if (config.semantic_registry) |registry| _ = registry.add(.{
        .element_id = id.id,
        .role = .spin_button,
        .label = config.semantic_label,
        .value_text = value_text,
        .value = @floatFromInt(value),
        .value_min = @floatFromInt(bounds.min),
        .value_max = @floatFromInt(bounds.max),
        .value_step = @floatFromInt(normalizedStep(config.step)),
        .disabled = config.disabled,
        .focused = config.focused,
    });

    clay.UI()(.{
        .id = id,
        .layout = .{
            .sizing = .{ .w = .fixed(width), .h = .fixed(theme.controls.control_height) },
            .child_alignment = .center,
        },
        .background_color = if (config.disabled) theme.controls.surface_disabled_soft else theme.controls.surface,
        .corner_radius = .all(theme.controls.radius_medium),
        .border = .{
            .color = theme.controls.focus,
            .width = if (config.focused) .outside(theme.controls.focus_width) else .{},
        },
    })({
        drawControl(decrement_id, "−", decrement_disabled, decrement_interaction);
        clay.UI()(.{
            .layout = .{
                .sizing = .{ .w = .grow, .h = .grow },
                .child_alignment = .center,
            },
        })({
            label.draw(value_text, .{
                .font_size = 16,
                .color = if (config.disabled) theme.controls.text_disabled else theme.controls.text,
            });
        });
        drawControl(increment_id, "+", increment_disabled, increment_interaction);
    });

    if (decrement_interaction.clicked) {
        return steppedValue(value, bounds.min, bounds.max, config.step, -1);
    }
    if (increment_interaction.clicked) {
        return steppedValue(value, bounds.min, bounds.max, config.step, 1);
    }
    if (!config.disabled and config.focused) {
        if (input.home_pressed) return bounds.min;
        if (input.end_pressed) return bounds.max;
        const decrement = input.left_pressed or input.down_pressed;
        const increment = input.right_pressed or input.up_pressed;
        if (decrement != increment) {
            return steppedValue(value, bounds.min, bounds.max, config.step, if (decrement) -1 else 1);
        }
    }
    return null;
}

pub fn decrementId(stepper_id: []const u8) clay.ElementId {
    return clay.ElementId.IDI(stepper_id, 0x20_000);
}

pub fn incrementId(stepper_id: []const u8) clay.ElementId {
    return clay.ElementId.IDI(stepper_id, 0x20_001);
}

pub fn steppedValue(value: i32, min: i32, max: i32, step: i32, direction: i8) i32 {
    const bounds = normalizedBounds(min, max);
    const current: i64 = clampValue(value, bounds.min, bounds.max);
    const delta = normalizedStep(step);
    const requested = if (direction < 0) current - delta else current + delta;
    return @intCast(@min(@max(requested, @as(i64, bounds.min)), @as(i64, bounds.max)));
}

fn drawControl(
    id: clay.ElementId,
    text: []const u8,
    disabled: bool,
    pointer: interaction.Result,
) void {
    const background = if (disabled)
        theme.controls.surface_disabled_soft
    else if (pointer.active)
        theme.controls.accent_pressed
    else if (pointer.hovered)
        theme.controls.surface_hover
    else
        theme.controls.surface_muted;
    clay.UI()(.{
        .id = id,
        .layout = .{
            .sizing = .{ .w = .fixed(theme.controls.control_height), .h = .grow },
            .child_alignment = .center,
        },
        .background_color = background,
        .corner_radius = .all(theme.controls.radius_medium),
    })({
        label.draw(text, .{
            .font_size = 20,
            .color = if (disabled) theme.controls.text_disabled else theme.controls.text,
        });
    });
}

const Bounds = struct { min: i32, max: i32 };

fn normalizedBounds(min: i32, max: i32) Bounds {
    return .{ .min = @min(min, max), .max = @max(min, max) };
}

fn clampValue(value: i32, min: i32, max: i32) i32 {
    return @min(@max(value, min), max);
}

fn normalizedStep(step: i32) i64 {
    const wide: i64 = step;
    return @max(if (wide < 0) -wide else wide, 1);
}

test "stepper clamps values and normalizes reversed bounds" {
    try std.testing.expectEqual(@as(i32, 5), steppedValue(4, 0, 5, 3, 1));
    try std.testing.expectEqual(@as(i32, 0), steppedValue(1, 0, 5, 3, -1));
    try std.testing.expectEqual(@as(i32, 4), steppedValue(2, 5, 0, 2, 1));
}

test "stepper normalizes zero negative and minimum integer steps" {
    try std.testing.expectEqual(@as(i32, 4), steppedValue(3, 0, 10, 0, 1));
    try std.testing.expectEqual(@as(i32, 6), steppedValue(3, 0, 10, -3, 1));
    try std.testing.expectEqual(@as(i32, 10), steppedValue(3, 0, 10, std.math.minInt(i32), 1));
}

test "stepper child ids do not collide with the container" {
    const container = clay.ElementId.ID("RetryStepper").id;
    try std.testing.expect(container != decrementId("RetryStepper").id);
    try std.testing.expect(container != incrementId("RetryStepper").id);
    try std.testing.expect(decrementId("RetryStepper").id != incrementId("RetryStepper").id);
}
