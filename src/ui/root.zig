const std = @import("std");
const clay = @import("zclay");
const Action = @import("../app/action.zig").Action;
const Model = @import("../app/model.zig").Model;
const font = @import("../text/font.zig");
const focus_manager = @import("focus_manager.zig");
const theme = @import("theme.zig");
const button = @import("widgets/button.zig");
const card = @import("widgets/card.zig");
const checkbox = @import("widgets/checkbox.zig");
const divider = @import("widgets/divider.zig");
const dialog = @import("widgets/dialog.zig");
const icon_button = @import("widgets/icon_button.zig");
const interaction = @import("widgets/interaction.zig");
const label = @import("widgets/label.zig");
const navigation_bar = @import("widgets/navigation_bar.zig");
const progress_bar = @import("widgets/progress_bar.zig");
const scroll_view = @import("widgets/scroll_view.zig");
const slider = @import("widgets/slider.zig");
const text_field = @import("widgets/text_field.zig");
const toast = @import("widgets/toast.zig");
const toggle_switch = @import("widgets/switch.zig");

const max_actions = 8;

const state = struct {
    var memory: ?[]u8 = null;
    var interaction_state: interaction.State = .{};
    var focus_state: focus_manager.State = .{};
    var toast_state: toast.State = .{};
    var last_text_submission_count: u32 = 0;
    var actions: [max_actions]Action = undefined;
    var action_count: usize = 0;
    var counter_text: [96]u8 = undefined;
    var confirmation_text: [96]u8 = undefined;
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
    state.focus_state = .{};
    state.toast_state = .{};
    state.last_text_submission_count = model.text_submission_count;
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
    state.focus_state = .{};
    state.toast_state = .{};
    state.last_text_submission_count = 0;
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
    clay.updateScrollContainers(true, .{
        .x = model.scroll_delta_x * 36,
        .y = model.scroll_delta_y * 36,
    }, @max(model.frame_delta_seconds, 1.0 / 240.0));
    if (model.text_submission_count != state.last_text_submission_count) {
        state.last_text_submission_count = model.text_submission_count;
        state.toast_state.show("文本已提交", 2.5);
    }
    state.toast_state.update(model.frame_delta_seconds);
    clay.beginLayout();

    const dialog_id = clay.ElementId.ID("DemoDialogPanel").id;
    const dialog_cancel_id = clay.ElementId.ID("DemoDialogCancel").id;
    const dialog_confirm_id = clay.ElementId.ID("DemoDialogConfirm").id;
    const primary_action_id = clay.ElementId.ID("PrimaryAction").id;
    const increment_progress_id = clay.ElementId.ID("IncrementProgress").id;
    const open_dialog_id = clay.ElementId.ID("OpenDemoDialog").id;
    const checkbox_id = clay.ElementId.ID("DemoCheckbox").id;
    const switch_id = clay.ElementId.ID("DemoSwitch").id;
    const slider_id = clay.ElementId.ID("VolumeSlider").id;
    const text_field_id = clay.ElementId.ID("DemoTextField").id;
    if (model.demo_dialog_open) {
        state.focus_state.openModal(dialog_id, dialog_confirm_id);
        state.focus_state.setOrder(&.{ dialog_cancel_id, dialog_confirm_id });
    } else {
        state.focus_state.closeModal(dialog_id);
        state.focus_state.setOrder(&.{
            clay.ElementId.IDI("MainNavigation", 0).id,
            clay.ElementId.IDI("MainNavigation", 1).id,
            clay.ElementId.IDI("MainNavigation", 2).id,
            primary_action_id,
            increment_progress_id,
            open_dialog_id,
            checkbox_id,
            switch_id,
            slider_id,
            text_field_id,
        });
    }
    if (model.focus_next_requested) {
        _ = state.focus_state.move(1);
    } else if (model.focus_previous_requested) {
        _ = state.focus_state.move(-1);
    }
    const focused_text_field = state.focus_state.isFocused(text_field_id) and !model.demo_dialog_open;
    if ((model.focus_next_requested or model.focus_previous_requested) and
        focused_text_field != model.text_field_focused)
    {
        emit(.{ .text_field_focus_changed = focused_text_field });
    }
    if (model.back_requested and model.text_field_focused and !model.demo_dialog_open) {
        emit(.{ .text_field_focus_changed = false });
    }

    const compact = model.viewport_width < 900;
    const narrow = model.viewport_width < 600;
    const content_direction: clay.LayoutDirection = if (compact) .top_to_bottom else .left_to_right;
    const control_direction: clay.LayoutDirection = if (narrow) .top_to_bottom else .left_to_right;
    const control_width: f32 = if (model.viewport_width < 420)
        @floatFromInt(@max(model.viewport_width - 160, 120))
    else
        260;
    const sidebar_sizing: clay.Sizing = if (compact)
        .{ .w = .grow, .h = .fixed(112) }
    else
        .{ .w = .fixed(240), .h = .grow };
    const input: interaction.Input = .{
        .x = model.pointer_x,
        .y = model.pointer_y,
        .down = model.pointer_down,
        .pressed = model.pointer_pressed,
        .released = model.pointer_released,
        .activate_pressed = model.focused_control_activate_requested,
        .left_pressed = model.focused_control_left_requested,
        .right_pressed = model.focused_control_right_requested,
    };
    const counter_text = std.fmt.bufPrint(
        &state.counter_text,
        "按钮点击次数：{d}",
        .{model.primary_button_presses},
    ) catch "按钮点击次数过多";
    const confirmation_text = std.fmt.bufPrint(
        &state.confirmation_text,
        "对话框确认次数：{d}",
        .{model.demo_dialog_confirmations},
    ) catch "对话框确认次数过多";
    const modal_open = state.focus_state.modalOpen();

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
                const nav_items = [_]navigation_bar.Item{
                    .{ .text = "首页" },
                    .{ .text = "活动" },
                    .{ .text = "设置" },
                };
                if (navigation_bar.draw(&state.interaction_state, input, .{
                    .id = "MainNavigation",
                    .items = &nav_items,
                    .selected_index = model.demo_navigation_index,
                    .item_width = if (compact) control_width else 208,
                    .direction = if (compact) .left_to_right else .top_to_bottom,
                    .disabled = modal_open,
                    .focused_id = state.focus_state.focused_id,
                })) |index| {
                    state.focus_state.focus(clay.ElementId.IDI("MainNavigation", @intCast(index)).id);
                    emit(.{ .demo_navigation_selected = @intCast(index) });
                }
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
                clay.UI()(card.declaration(.{
                    .id = "PrimaryCard",
                    .scroll_vertical = true,
                }))({
                    label.draw("Clay 应用框架", .{ .font_size = 22 });
                    label.draw(counter_text, .{ .color = .{ 166, 187, 218, 255 } });
                    clay.UI()(.{ .layout = .{
                        .sizing = .{ .w = .grow, .h = .fit },
                        .child_gap = 12,
                        .direction = control_direction,
                    } })({
                        if (button.draw(&state.interaction_state, input, .{
                            .id = "PrimaryAction",
                            .text = "点击测试",
                            .width = control_width,
                            .disabled = modal_open,
                            .focused = state.focus_state.isFocused(primary_action_id),
                        })) {
                            state.focus_state.focus(primary_action_id);
                            emit(.primary_button_pressed);
                        }
                        if (icon_button.draw(&state.interaction_state, input, .{
                            .id = "IncrementProgress",
                            .icon = "+",
                            .disabled = modal_open,
                            .focused = state.focus_state.isFocused(increment_progress_id),
                        })) {
                            state.focus_state.focus(increment_progress_id);
                            emit(.demo_progress_incremented);
                        }
                        if (button.draw(&state.interaction_state, input, .{
                            .id = "OpenDemoDialog",
                            .text = "打开对话框",
                            .width = 168,
                            .disabled = modal_open,
                            .focused = state.focus_state.isFocused(open_dialog_id),
                        })) {
                            state.focus_state.focus(open_dialog_id);
                            emit(.demo_dialog_opened);
                        }
                    });
                    divider.draw(.{});
                    clay.UI()(.{ .layout = .{
                        .sizing = .{ .w = .grow, .h = .fit },
                        .child_gap = 24,
                        .direction = control_direction,
                    } })({
                        if (checkbox.draw(&state.interaction_state, input, .{
                            .id = "DemoCheckbox",
                            .text = "启用离线缓存",
                            .checked = model.demo_checkbox_checked,
                            .width = control_width,
                            .disabled = modal_open,
                            .focused = state.focus_state.isFocused(checkbox_id),
                        })) {
                            state.focus_state.focus(checkbox_id);
                            emit(.demo_checkbox_toggled);
                        }
                        if (toggle_switch.draw(&state.interaction_state, input, .{
                            .id = "DemoSwitch",
                            .text = "接收应用通知",
                            .checked = model.demo_switch_checked,
                            .width = control_width,
                            .disabled = modal_open,
                            .focused = state.focus_state.isFocused(switch_id),
                        })) {
                            state.focus_state.focus(switch_id);
                            emit(.demo_switch_toggled);
                        }
                    });
                    label.draw("任务进度（点击 + 增加）", .{ .color = .{ 166, 187, 218, 255 } });
                    progress_bar.draw(.{ .value = model.demo_progress, .width = control_width });
                    label.draw("媒体音量", .{ .color = .{ 166, 187, 218, 255 } });
                    if (slider.draw(&state.interaction_state, input, .{
                        .id = "VolumeSlider",
                        .value = model.demo_volume,
                        .width = control_width,
                        .disabled = modal_open,
                        .focused = state.focus_state.isFocused(slider_id),
                    })) |value| {
                        state.focus_state.focus(slider_id);
                        emit(.{ .demo_volume_changed = value });
                    }
                    label.draw("单行文本输入", .{ .color = .{ 166, 187, 218, 255 } });
                    const text_result = text_field.draw(&state.interaction_state, input, .{
                        .id = "DemoTextField",
                        .text = model.text(),
                        .placeholder = "输入中文或英文，按 Enter 提交",
                        .cursor = model.text_cursor,
                        .selection_anchor = model.text_selection_anchor,
                        .width = control_width,
                        .focused = model.text_field_focused,
                        .disabled = modal_open,
                    });
                    if (text_result.focus_requested and !model.text_field_focused) {
                        state.focus_state.focus(text_field_id);
                        emit(.{ .text_field_focus_changed = true });
                    } else if (text_result.blur_requested) {
                        emit(.{ .text_field_focus_changed = false });
                    }
                    label.draw(confirmation_text, .{ .color = .{ 145, 171, 207, 255 } });
                });

                clay.UI()(scroll_view.declaration(.{
                    .id = "ActivityScrollView",
                    .height = if (compact) 112 else 144,
                    .background_color = .{ 24, 56, 70, 255 },
                }))({
                    label.draw("最近活动", .{ .font_size = 18, .color = .{ 155, 211, 207, 255 } });
                    inline for ([_][]const u8{
                        "中文字体已通过 Fontstash 接入 Sokol",
                        "Button 点击状态已接入 reducer",
                        "Checkbox 设置已保存到 AppModel",
                        "Switch 通知状态已更新",
                        "ProgressBar 使用受控数值",
                        "ScrollView 已启用垂直裁剪",
                        "鼠标滚轮事件由 Sokol 转发",
                        "触摸拖动由 Clay 管理",
                    }) |activity| {
                        clay.UI()(.{
                            .layout = .{
                                .sizing = .{ .w = .grow, .h = .fixed(36) },
                                .padding = .axes(10, 8),
                                .child_alignment = .{ .y = .center },
                            },
                            .background_color = .{ 28, 65, 79, 255 },
                            .corner_radius = .all(7),
                        })({
                            label.draw(activity, .{ .color = .{ 177, 220, 216, 255 } });
                        });
                    }
                });
            });
        });
    });

    if (model.demo_dialog_open) {
        const dialog_width: f32 = @min(420, @as(f32, @floatFromInt(@max(model.viewport_width - 48, 240))));
        const dialog_result = dialog.draw(&state.interaction_state, input, .{
            .overlay_id = "DemoDialogOverlay",
            .panel_id = "DemoDialogPanel",
            .cancel_id = "DemoDialogCancel",
            .confirm_id = "DemoDialogConfirm",
            .title = "确认操作",
            .message = "这是由 Clay 构建的模态对话框。底层控件已禁用，Escape 和 Android 返回键可以关闭它。",
            .viewport_width = @floatFromInt(@max(model.viewport_width, 1)),
            .viewport_height = @floatFromInt(@max(model.viewport_height, 1)),
            .width = dialog_width,
            .focused_id = state.focus_state.focused_id,
        });
        if (dialog_result.confirmed) {
            emit(.demo_dialog_confirmed);
        } else if (dialog_result.close_requested or model.back_requested) {
            emit(.demo_dialog_closed);
        }
    }
    toast.draw(&state.toast_state, @floatFromInt(@max(model.viewport_width, 1)));

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
    var scissor_count: usize = 0;
    for (result.commands) |command| {
        if (command.command_type == .rectangle) rectangle_count += 1;
        if (command.command_type == .text) text_count += 1;
        if (command.command_type == .scissor_start) scissor_count += 1;
    }

    try std.testing.expect(rectangle_count >= 14);
    try std.testing.expect(text_count >= 14);
    try std.testing.expect(scissor_count >= 2);
    try std.testing.expectEqual(@as(usize, 0), result.actions.len);
    try std.testing.expect(result.clear_color.a == 1);

    model.text_submission_count = 1;
    const toast_frame = build(&model);
    var has_toast_command = false;
    for (toast_frame.commands) |command| {
        if (command.z_index == 200 and command.command_type == .rectangle) {
            has_toast_command = true;
            break;
        }
    }
    try std.testing.expect(has_toast_command);

    model.demo_dialog_open = true;
    model.back_requested = true;
    const dialog_frame = build(&model);
    var has_modal_command = false;
    for (dialog_frame.commands) |command| {
        if (command.z_index == 100 and command.command_type == .rectangle) {
            has_modal_command = true;
            break;
        }
    }
    var requested_close = false;
    for (dialog_frame.actions) |action| {
        switch (action) {
            .demo_dialog_closed => requested_close = true,
            else => {},
        }
    }

    try std.testing.expect(has_modal_command);
    try std.testing.expect(requested_close);
    try std.testing.expect(state.focus_state.modalOpen());
}
