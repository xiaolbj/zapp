const std = @import("std");
const clay = @import("zclay");
const Action = @import("../app/action.zig").Action;
const Model = @import("../app/model.zig").Model;
const font = @import("../text/font.zig");
const theme = @import("theme.zig");
const button = @import("widgets/button.zig");
const checkbox = @import("widgets/checkbox.zig");
const interaction = @import("widgets/interaction.zig");
const label = @import("widgets/label.zig");
const toggle_switch = @import("widgets/switch.zig");

const max_actions = 8;

const state = struct {
    var memory: ?[]u8 = null;
    var interaction_state: interaction.State = .{};
    var actions: [max_actions]Action = undefined;
    var action_count: usize = 0;
    var counter_text: [96]u8 = undefined;
};

pub const Frame = struct {
    clear_color: theme.Color,
    commands: []const clay.RenderCommand,
    actions: []const Action,
};

pub fn setup(model: *const Model) bool {
    if (state.memory != null) return true;

    const memory = std.heap.c_allocator.alloc(u8, clay.minMemorySize()) catch {
        std.log.err("failed to allocate Clay arena", .{});
        return false;
    };
    state.memory = memory;
    state.interaction_state = .{};
    state.action_count = 0;

    _ = clay.initialize(.init(memory), dimensions(model), .{
        .error_handler_function = clayError,
    });
    clay.setMeasureTextFunction(void, {}, font.measure);
    return true;
}

pub fn shutdown() void {
    if (state.memory) |memory| {
        std.heap.c_allocator.free(memory);
        state.memory = null;
    }
    state.interaction_state = .{};
    state.action_count = 0;
}

/// Builds the responsive product shell and reports semantic UI actions.
pub fn build(model: *const Model) Frame {
    state.action_count = 0;
    if (state.memory == null) return .{
        .clear_color = theme.dark.background,
        .commands = &.{},
        .actions = &.{},
    };

    clay.setLayoutDimensions(dimensions(model));
    clay.setPointerState(.{ .x = model.pointer_x, .y = model.pointer_y }, model.pointer_down);
    clay.beginLayout();

    const compact = model.viewport_width < 900;
    const content_direction: clay.LayoutDirection = if (compact) .top_to_bottom else .left_to_right;
    const sidebar_sizing: clay.Sizing = if (compact)
        .{ .w = .grow, .h = .fixed(112) }
    else
        .{ .w = .fixed(240), .h = .grow };
    const input: interaction.Input = .{
        .down = model.pointer_down,
        .pressed = model.pointer_pressed,
        .released = model.pointer_released,
    };
    const counter_text = std.fmt.bufPrint(
        &state.counter_text,
        "按钮点击次数：{d}",
        .{model.primary_button_presses},
    ) catch "按钮点击次数过多";

    clay.UI()(.{
        .id = .ID("AppRoot"),
        .layout = .{
            .sizing = .grow,
            .padding = .all(24),
            .child_gap = 16,
            .direction = .top_to_bottom,
        },
        .background_color = clayColor(theme.dark.background),
    })({
        clay.UI()(.{
            .id = .ID("Header"),
            .layout = .{
                .sizing = .{ .w = .grow, .h = .fixed(88) },
                .padding = .all(16),
                .child_alignment = .{ .y = .center },
            },
            .background_color = .{ 41, 89, 154, 255 },
            .corner_radius = .all(12),
        })({
            label.draw("ZAPP 跨平台应用", .{ .font_size = 28, .color = .{ 244, 248, 255, 255 } });
        });

        clay.UI()(.{
            .id = .ID("Content"),
            .layout = .{
                .sizing = .grow,
                .child_gap = 16,
                .direction = content_direction,
            },
        })({
            clay.UI()(.{
                .id = .ID("Sidebar"),
                .layout = .{
                    .sizing = sidebar_sizing,
                    .padding = .all(16),
                },
                .background_color = if (clay.hovered()) .{ 31, 49, 77, 255 } else .{ 24, 36, 58, 255 },
                .corner_radius = .all(12),
            })({
                label.draw("导航", .{ .color = .{ 155, 178, 211, 255 } });
            });

            clay.UI()(.{
                .id = .ID("MainPanel"),
                .layout = .{
                    .sizing = .grow,
                    .padding = .all(16),
                    .child_gap = 16,
                    .direction = .top_to_bottom,
                },
                .background_color = .{ 18, 27, 44, 255 },
                .corner_radius = .all(12),
            })({
                clay.UI()(.{
                    .id = .ID("PrimaryCard"),
                    .layout = .{
                        .sizing = .grow,
                        .padding = .all(24),
                        .child_gap = 16,
                        .direction = .top_to_bottom,
                    },
                    .background_color = .{ 31, 45, 70, 255 },
                    .corner_radius = .all(12),
                })({
                    label.draw("Clay 应用框架", .{ .font_size = 22 });
                    label.draw(counter_text, .{ .color = .{ 166, 187, 218, 255 } });
                    if (button.draw(&state.interaction_state, input, .{
                        .id = "PrimaryAction",
                        .text = "点击测试",
                    })) emit(.primary_button_pressed);
                    if (checkbox.draw(&state.interaction_state, input, .{
                        .id = "DemoCheckbox",
                        .text = "启用离线缓存",
                        .checked = model.demo_checkbox_checked,
                    })) emit(.demo_checkbox_toggled);
                    if (toggle_switch.draw(&state.interaction_state, input, .{
                        .id = "DemoSwitch",
                        .text = "接收应用通知",
                        .checked = model.demo_switch_checked,
                    })) emit(.demo_switch_toggled);
                });

                clay.UI()(.{
                    .id = .ID("SecondaryCard"),
                    .layout = .{
                        .sizing = .{ .w = .grow, .h = .fixed(104) },
                        .padding = .all(16),
                        .child_alignment = .{ .y = .center },
                    },
                    .background_color = .{ 24, 56, 70, 255 },
                    .corner_radius = .all(12),
                })({
                    label.draw("中文字体已通过 Fontstash 接入 Sokol", .{ .color = .{ 155, 211, 207, 255 } });
                });
            });
        });
    });

    return .{
        .clear_color = theme.dark.background,
        .commands = clay.endLayout(),
        .actions = state.actions[0..state.action_count],
    };
}

fn emit(action: Action) void {
    if (state.action_count == state.actions.len) {
        std.log.warn("UI action buffer is full", .{});
        return;
    }
    state.actions[state.action_count] = action;
    state.action_count += 1;
}

fn dimensions(model: *const Model) clay.Dimensions {
    return .{
        .w = @floatFromInt(@max(model.viewport_width, 1)),
        .h = @floatFromInt(@max(model.viewport_height, 1)),
    };
}

fn clayColor(color: theme.Color) clay.Color {
    return .{ color.r * 255, color.g * 255, color.b * 255, color.a * 255 };
}

fn clayError(data: clay.ErrorData) callconv(.c) void {
    const message = data.error_text.chars[0..@intCast(data.error_text.length)];
    std.log.err("Clay: {s}", .{message});
}

test "responsive shell emits controls and text" {
    var model: Model = .{};
    try std.testing.expect(setup(&model));
    defer shutdown();

    const result = build(&model);
    var rectangle_count: usize = 0;
    var text_count: usize = 0;
    for (result.commands) |command| {
        if (command.command_type == .rectangle) rectangle_count += 1;
        if (command.command_type == .text) text_count += 1;
    }

    try std.testing.expect(rectangle_count >= 6);
    try std.testing.expect(text_count >= 6);
    try std.testing.expectEqual(@as(usize, 0), result.actions.len);
    try std.testing.expect(result.clear_color.a == 1);
}
