const std = @import("std");
const clay = @import("zclay");
const Action = @import("../app/action.zig").Action;
const Model = @import("../app/model.zig").Model;
const font = @import("../text/font.zig");
const focus_manager = @import("focus_manager.zig");
const semantics = @import("semantics.zig");
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
const tree_view = @import("widgets/tree_view.zig");
const toggle_switch = @import("widgets/switch.zig");

const max_actions = 8;

const demo_tree_items = [_]tree_view.Item{
    .{ .text = "zapp" },
    .{ .text = "src", .parent_index = 0 },
    .{ .text = "app", .parent_index = 1 },
    .{ .text = "ui", .parent_index = 1 },
    .{ .text = "render", .parent_index = 1 },
    .{ .text = "assets", .parent_index = 0 },
    .{ .text = "README.md", .parent_index = 0 },
};

const state = struct {
    var memory: ?[]u8 = null;
    var interaction_state: interaction.State = .{};
    var focus_state: focus_manager.State = .{};
    var semantic_registry: semantics.Registry = .{};
    var toast_state: toast.State = .{};
    var last_text_submission_count: u32 = 0;
    var actions: [max_actions]Action = undefined;
    var action_count: usize = 0;
    var counter_text: [96]u8 = undefined;
    var confirmation_text: [96]u8 = undefined;
    var permission_status_text: [160]u8 = undefined;
    var file_status_text: [256]u8 = undefined;
    var file_metadata_text: [512]u8 = undefined;
    var file_preview_text: [768]u8 = undefined;
    var file_stream_status_text: [320]u8 = undefined;
};

pub const Frame = struct {
    clear_color: theme.Color,
    commands: []const clay.RenderCommand,
    actions: []const Action,
    semantic_nodes: []const semantics.Node,
};

pub const SemanticAction = enum {
    focus,
    activate,
    increment,
    decrement,
    set_text,
    expand,
    collapse,
    scroll_forward,
    scroll_backward,
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
    state.semantic_registry.reset();
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
    state.semantic_registry.reset();
    state.toast_state = .{};
    state.last_text_submission_count = 0;
    state.action_count = 0;
}

/// Builds the responsive product shell and reports semantic UI actions.
pub fn build(model: *const Model) Frame {
    state.action_count = 0;
    state.semantic_registry.reset();
    if (state.memory == null) return .{
        .clear_color = theme.dark.background,
        .commands = &.{},
        .actions = &.{},
        .semantic_nodes = &.{},
    };

    clay.setLayoutDimensions(dimensions(model));
    clay.setPointerState(.{ .x = model.pointer_x, .y = model.pointer_y }, model.pointer_down);
    applySemanticScroll(model);
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
    const permission_button_id = clay.ElementId.ID("RequestCameraPermission").id;
    const file_picker_button_id = clay.ElementId.ID("OpenFilePicker").id;
    const file_stream_button_id = clay.ElementId.ID("StreamSelectedFile").id;
    if (model.demo_dialog_open) {
        state.focus_state.openModal(dialog_id, dialog_confirm_id);
        state.focus_state.setOrder(&.{ dialog_cancel_id, dialog_confirm_id });
    } else {
        state.focus_state.closeModal(dialog_id);
        var focus_order: [32]u32 = undefined;
        const base_order = [_]u32{
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
            permission_button_id,
            file_picker_button_id,
            file_stream_button_id,
        };
        @memcpy(focus_order[0..base_order.len], &base_order);
        var focus_order_count = base_order.len;
        for (demo_tree_items, 0..) |_, tree_index| {
            if (tree_view.isVisible(&demo_tree_items, tree_index, model.demo_tree_expanded_mask)) {
                focus_order[focus_order_count] = tree_view.itemId("ProjectTree", tree_index).id;
                focus_order_count += 1;
            }
        }
        state.focus_state.setOrder(focus_order[0..focus_order_count]);
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
    const permission_status_text = if (model.permission_request_pending)
        "权限状态：等待系统响应…"
    else if (model.last_permission) |permission|
        std.fmt.bufPrint(
            &state.permission_status_text,
            "{s}权限：{s}",
            .{ permissionName(permission), if (model.last_permission_granted) "已授权" else "未授权或平台不支持" },
        ) catch "权限状态不可用"
    else
        "权限状态：尚未请求";
    const file_status_text = if (model.file_picker_pending)
        "文件选择：等待系统响应…"
    else if (model.selectedFileUri().len > 0)
        std.fmt.bufPrint(
            &state.file_status_text,
            "已选择：{s}",
            .{utf8Prefix(model.selectedFileUri(), 180)},
        ) catch "文件 URI 过长"
    else if (model.file_selection_cancel_count > 0)
        "文件选择：已取消或平台不支持"
    else
        "文件选择：尚未选择";
    const file_metadata_text = formatFileMetadata(&state.file_metadata_text, model);
    const file_preview_text = formatFilePreview(&state.file_preview_text, model);
    const file_stream_status_text = formatFileStreamStatus(&state.file_stream_status_text, model);
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
            label.draw("ZAPP 跨平台应用", .{
                .font_size = 28,
                .color = .{ 244, 248, 255, 255 },
                .semantic_id = .ID("AppTitle"),
                .semantic_registry = &state.semantic_registry,
            });
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
                    .semantic_label = "主导航",
                    .semantic_registry = &state.semantic_registry,
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
                    .semantic_label = "控件示例",
                    .semantic_registry = &state.semantic_registry,
                }))({
                    label.draw("Clay 应用框架", .{
                        .font_size = 22,
                        .semantic_id = .ID("PrimaryCardTitle"),
                        .semantic_registry = &state.semantic_registry,
                    });
                    label.draw(counter_text, .{
                        .color = .{ 166, 187, 218, 255 },
                        .semantic_id = .ID("ButtonPressCount"),
                        .semantic_registry = &state.semantic_registry,
                    });
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
                            .semantic_registry = &state.semantic_registry,
                        })) {
                            state.focus_state.focus(primary_action_id);
                            emit(.primary_button_pressed);
                        }
                        if (icon_button.draw(&state.interaction_state, input, .{
                            .id = "IncrementProgress",
                            .icon = "+",
                            .disabled = modal_open,
                            .focused = state.focus_state.isFocused(increment_progress_id),
                            .semantic_label = "增加任务进度",
                            .semantic_registry = &state.semantic_registry,
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
                            .semantic_registry = &state.semantic_registry,
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
                            .semantic_registry = &state.semantic_registry,
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
                            .semantic_registry = &state.semantic_registry,
                        })) {
                            state.focus_state.focus(switch_id);
                            emit(.demo_switch_toggled);
                        }
                    });
                    label.draw("任务进度（点击 + 增加）", .{
                        .color = .{ 166, 187, 218, 255 },
                        .semantic_id = .ID("ProgressLabel"),
                        .semantic_registry = &state.semantic_registry,
                    });
                    progress_bar.draw(.{
                        .id = "TaskProgress",
                        .value = model.demo_progress,
                        .width = control_width,
                        .semantic_label = "任务进度",
                        .semantic_registry = &state.semantic_registry,
                    });
                    label.draw("媒体音量", .{
                        .color = .{ 166, 187, 218, 255 },
                        .semantic_id = .ID("VolumeLabel"),
                        .semantic_registry = &state.semantic_registry,
                    });
                    if (slider.draw(&state.interaction_state, input, .{
                        .id = "VolumeSlider",
                        .value = model.demo_volume,
                        .width = control_width,
                        .disabled = modal_open,
                        .focused = state.focus_state.isFocused(slider_id),
                        .semantic_label = "媒体音量",
                        .semantic_registry = &state.semantic_registry,
                    })) |value| {
                        state.focus_state.focus(slider_id);
                        emit(.{ .demo_volume_changed = value });
                    }
                    label.draw("单行文本输入", .{
                        .color = .{ 166, 187, 218, 255 },
                        .semantic_id = .ID("TextFieldLabel"),
                        .semantic_registry = &state.semantic_registry,
                    });
                    const text_result = text_field.draw(&state.interaction_state, input, .{
                        .id = "DemoTextField",
                        .text = model.text(),
                        .placeholder = "输入中文或英文，按 Enter 提交",
                        .cursor = model.text_cursor,
                        .selection_anchor = model.text_selection_anchor,
                        .composition = model.textComposition(),
                        .width = control_width,
                        .focused = model.text_field_focused,
                        .disabled = modal_open,
                        .semantic_label = "单行文本输入",
                        .semantic_registry = &state.semantic_registry,
                    });
                    if (text_result.focus_requested and !model.text_field_focused) {
                        state.focus_state.focus(text_field_id);
                        emit(.{ .text_field_focus_changed = true });
                    } else if (text_result.blur_requested) {
                        emit(.{ .text_field_focus_changed = false });
                    }
                    if (text_result.cursor_position) |position| {
                        emit(.{ .text_cursor_set = .{
                            .position = position,
                            .selecting = text_result.selecting,
                        } });
                    }
                    divider.draw(.{});
                    label.draw("平台 API", .{
                        .font_size = 18,
                        .color = theme.controls.text_muted,
                        .semantic_id = .ID("PlatformApiLabel"),
                        .semantic_registry = &state.semantic_registry,
                    });
                    clay.UI()(.{ .layout = .{
                        .sizing = .{ .w = .grow, .h = .fit },
                        .child_gap = 12,
                        .direction = control_direction,
                    } })({
                        if (button.draw(&state.interaction_state, input, .{
                            .id = "RequestCameraPermission",
                            .text = if (model.permission_request_pending) "请求中…" else "请求相机权限",
                            .width = control_width,
                            .disabled = modal_open or model.permission_request_pending,
                            .focused = state.focus_state.isFocused(permission_button_id),
                            .semantic_registry = &state.semantic_registry,
                        })) {
                            state.focus_state.focus(permission_button_id);
                            emit(.{ .platform_permission_requested = .camera });
                        }
                        if (button.draw(&state.interaction_state, input, .{
                            .id = "OpenFilePicker",
                            .text = if (model.file_picker_pending) "选择中…" else "选择文件",
                            .width = control_width,
                            .disabled = modal_open or model.file_picker_pending or model.file_stream_pending,
                            .focused = state.focus_state.isFocused(file_picker_button_id),
                            .semantic_registry = &state.semantic_registry,
                        })) {
                            state.focus_state.focus(file_picker_button_id);
                            emit(.platform_file_picker_requested);
                        }
                        if (button.draw(&state.interaction_state, input, .{
                            .id = "StreamSelectedFile",
                            .text = if (model.file_stream_cancel_pending)
                                "取消中…"
                            else if (model.file_stream_pending)
                                "取消完整读取"
                            else
                                "读取完整文件",
                            .width = control_width,
                            .disabled = modal_open or model.selectedFileUri().len == 0 or
                                model.file_read_pending or model.file_stream_cancel_pending,
                            .focused = state.focus_state.isFocused(file_stream_button_id),
                            .semantic_registry = &state.semantic_registry,
                        })) {
                            state.focus_state.focus(file_stream_button_id);
                            emit(if (model.file_stream_pending)
                                .platform_file_stream_cancel_requested
                            else
                                .platform_file_stream_requested);
                        }
                    });
                    label.draw(permission_status_text, .{
                        .color = theme.controls.text_muted,
                        .semantic_id = .ID("PermissionStatus"),
                        .semantic_registry = &state.semantic_registry,
                    });
                    label.draw(file_status_text, .{
                        .color = theme.controls.text_muted,
                        .semantic_id = .ID("FileSelectionStatus"),
                        .semantic_registry = &state.semantic_registry,
                    });
                    if (file_metadata_text.len > 0) label.draw(file_metadata_text, .{
                        .color = theme.controls.text_muted,
                        .wrap_mode = .words,
                        .semantic_id = .ID("FileMetadataStatus"),
                        .semantic_registry = &state.semantic_registry,
                    });
                    if (file_preview_text.len > 0) label.draw(file_preview_text, .{
                        .color = theme.controls.text_muted,
                        .semantic_id = .ID("FilePreviewStatus"),
                        .semantic_registry = &state.semantic_registry,
                    });
                    if (file_stream_status_text.len > 0) label.draw(file_stream_status_text, .{
                        .color = theme.controls.text_muted,
                        .wrap_mode = .words,
                        .semantic_id = .ID("FileStreamStatus"),
                        .semantic_registry = &state.semantic_registry,
                    });
                    label.draw(confirmation_text, .{
                        .color = .{ 145, 171, 207, 255 },
                        .semantic_id = .ID("DialogConfirmationCount"),
                        .semantic_registry = &state.semantic_registry,
                    });
                    label.draw("项目结构", .{
                        .font_size = 18,
                        .color = theme.controls.text_muted,
                        .semantic_id = .ID("ProjectTreeLabel"),
                        .semantic_registry = &state.semantic_registry,
                    });
                    const tree_result = tree_view.draw(&state.interaction_state, input, .{
                        .id = "ProjectTree",
                        .items = &demo_tree_items,
                        .expanded_mask = model.demo_tree_expanded_mask,
                        .selected_index = model.demo_tree_selected_index,
                        .focused_id = state.focus_state.focused_id,
                        .width = control_width,
                        .disabled = modal_open,
                        .semantic_label = "项目结构",
                        .semantic_registry = &state.semantic_registry,
                    });
                    if (tree_result.focus_index) |index| {
                        state.focus_state.focus(tree_view.itemId("ProjectTree", index).id);
                    }
                    if (tree_result.toggled_index) |index| {
                        state.focus_state.focus(tree_view.itemId("ProjectTree", index).id);
                        emit(.{ .demo_tree_toggled = @intCast(index) });
                    }
                    if (tree_result.selected_index) |index| {
                        state.focus_state.focus(tree_view.itemId("ProjectTree", index).id);
                        emit(.{ .demo_tree_selected = @intCast(index) });
                    }
                });

                clay.UI()(scroll_view.declaration(.{
                    .id = "ActivityScrollView",
                    .height = if (compact) 112 else 144,
                    .background_color = .{ 24, 56, 70, 255 },
                    .semantic_label = "最近活动",
                    .semantic_registry = &state.semantic_registry,
                }))({
                    label.draw("最近活动", .{
                        .font_size = 18,
                        .color = .{ 155, 211, 207, 255 },
                        .semantic_id = .ID("ActivityTitle"),
                        .semantic_registry = &state.semantic_registry,
                    });
                    inline for ([_][]const u8{
                        "中文字体已通过 Fontstash 接入 Sokol",
                        "Button 点击状态已接入 reducer",
                        "Checkbox 设置已保存到 AppModel",
                        "Switch 通知状态已更新",
                        "ProgressBar 使用受控数值",
                        "ScrollView 已启用垂直裁剪",
                        "鼠标滚轮事件由 Sokol 转发",
                        "触摸拖动由 Clay 管理",
                    }, 0..) |activity, activity_index| {
                        clay.UI()(.{
                            .layout = .{
                                .sizing = .{ .w = .grow, .h = .fixed(36) },
                                .padding = .axes(10, 8),
                                .child_alignment = .{ .y = .center },
                            },
                            .background_color = .{ 28, 65, 79, 255 },
                            .corner_radius = .all(7),
                        })({
                            label.draw(activity, .{
                                .color = .{ 177, 220, 216, 255 },
                                .semantic_id = .IDI("ActivityItem", @intCast(activity_index)),
                                .semantic_registry = &state.semantic_registry,
                            });
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
            .semantic_registry = &state.semantic_registry,
        });
        if (dialog_result.confirmed) {
            emit(.demo_dialog_confirmed);
        } else if (dialog_result.close_requested or model.back_requested) {
            emit(.demo_dialog_closed);
        }
    }
    toast.draw(&state.toast_state, .{
        .viewport_width = @floatFromInt(@max(model.viewport_width, 1)),
        .semantic_registry = &state.semantic_registry,
    });

    const commands = clay.endLayout();
    state.semantic_registry.resolveBounds();
    return .{
        .clear_color = theme.dark.background,
        .commands = commands,
        .actions = state.actions[0..state.action_count],
        .semantic_nodes = state.semantic_registry.items(),
    };
}

/// Converts a platform accessibility action back into the same App actions
/// used by pointer and keyboard interaction. The returned slice is consumed
/// synchronously before the next `build()` call.
pub fn handleSemanticAction(
    model: *const Model,
    element_id: u32,
    semantic_action: SemanticAction,
    text: []const u8,
) []const Action {
    state.action_count = 0;
    const primary_id = clay.ElementId.ID("PrimaryAction").id;
    const progress_id = clay.ElementId.ID("IncrementProgress").id;
    const dialog_open_id = clay.ElementId.ID("OpenDemoDialog").id;
    const checkbox_id = clay.ElementId.ID("DemoCheckbox").id;
    const switch_id = clay.ElementId.ID("DemoSwitch").id;
    const slider_id = clay.ElementId.ID("VolumeSlider").id;
    const text_field_id = clay.ElementId.ID("DemoTextField").id;
    const permission_id = clay.ElementId.ID("RequestCameraPermission").id;
    const file_picker_id = clay.ElementId.ID("OpenFilePicker").id;
    const file_stream_id = clay.ElementId.ID("StreamSelectedFile").id;
    const dialog_cancel_id = clay.ElementId.ID("DemoDialogCancel").id;
    const dialog_confirm_id = clay.ElementId.ID("DemoDialogConfirm").id;

    if (model.demo_dialog_open and element_id != dialog_cancel_id and element_id != dialog_confirm_id) {
        return state.actions[0..0];
    }

    switch (semantic_action) {
        .focus => {
            if (isInteractiveSemanticId(element_id)) {
                state.focus_state.focus(element_id);
                if (model.text_field_focused != (element_id == text_field_id)) {
                    emit(.{ .text_field_focus_changed = element_id == text_field_id });
                }
            }
        },
        .activate => {
            state.focus_state.focus(element_id);
            if (model.text_field_focused and element_id != text_field_id) {
                emit(.{ .text_field_focus_changed = false });
            }
            if (element_id == primary_id) emit(.primary_button_pressed) else if (element_id == progress_id) emit(.demo_progress_incremented) else if (element_id == dialog_open_id) emit(.demo_dialog_opened) else if (element_id == checkbox_id) emit(.demo_checkbox_toggled) else if (element_id == switch_id) emit(.demo_switch_toggled) else if (element_id == text_field_id) {
                if (!model.text_field_focused) emit(.{ .text_field_focus_changed = true });
            } else if (element_id == permission_id) emit(.{ .platform_permission_requested = .camera }) else if (element_id == file_picker_id) {
                if (!model.file_picker_pending and !model.file_stream_pending) {
                    emit(.platform_file_picker_requested);
                }
            } else if (element_id == file_stream_id) {
                if (model.file_stream_pending and !model.file_stream_cancel_pending) {
                    emit(.platform_file_stream_cancel_requested);
                } else if (!model.file_stream_pending and !model.file_read_pending and model.selectedFileUri().len > 0) {
                    emit(.platform_file_stream_requested);
                }
            } else if (element_id == dialog_cancel_id) emit(.demo_dialog_closed) else if (element_id == dialog_confirm_id) emit(.demo_dialog_confirmed) else if (navigationIndex(element_id)) |index| emit(.{ .demo_navigation_selected = index }) else if (treeIndex(element_id)) |index| emit(.{ .demo_tree_selected = index });
        },
        .increment, .decrement => if (element_id == slider_id) {
            const delta: f32 = if (semantic_action == .increment) 0.05 else -0.05;
            emit(.{ .demo_volume_changed = @min(@max(model.demo_volume + delta, 0), 1) });
        },
        .set_text => if (element_id == text_field_id) {
            state.focus_state.focus(element_id);
            if (!model.text_field_focused) emit(.{ .text_field_focus_changed = true });
            emit(.text_select_all);
            emit(.{ .text_inserted = text });
        },
        .expand, .collapse => if (treeIndex(element_id)) |index| {
            const expanded = model.demo_tree_expanded_mask & (@as(u64, 1) << @intCast(index)) != 0;
            const should_expand = semantic_action == .expand;
            if (treeHasChildren(index) and expanded != should_expand) {
                state.focus_state.focus(element_id);
                emit(.{ .demo_tree_toggled = index });
            }
        },
        .scroll_forward, .scroll_backward => if (isScrollableSemanticId(element_id)) {
            emit(.{ .semantic_scroll_requested = .{
                .element_id = element_id,
                .direction = if (semantic_action == .scroll_forward) 1 else -1,
            } });
        },
    }
    return state.actions[0..state.action_count];
}

fn navigationIndex(element_id: u32) ?u8 {
    for (0..3) |index| {
        if (element_id == clay.ElementId.IDI("MainNavigation", @intCast(index)).id) return @intCast(index);
    }
    return null;
}

fn treeIndex(element_id: u32) ?u8 {
    for (demo_tree_items, 0..) |_, index| {
        if (element_id == tree_view.itemId("ProjectTree", index).id) return @intCast(index);
    }
    return null;
}

fn treeHasChildren(index: u8) bool {
    for (demo_tree_items) |item| if (item.parent_index == index) return true;
    return false;
}

fn isInteractiveSemanticId(element_id: u32) bool {
    if (navigationIndex(element_id) != null or treeIndex(element_id) != null) return true;
    inline for ([_][]const u8{
        "PrimaryAction",
        "IncrementProgress",
        "OpenDemoDialog",
        "DemoCheckbox",
        "DemoSwitch",
        "VolumeSlider",
        "DemoTextField",
        "RequestCameraPermission",
        "OpenFilePicker",
        "StreamSelectedFile",
        "DemoDialogCancel",
        "DemoDialogConfirm",
    }) |id| if (element_id == clay.ElementId.ID(id).id) return true;
    return false;
}

fn isScrollableSemanticId(element_id: u32) bool {
    return element_id == clay.ElementId.ID("PrimaryCard").id or
        element_id == clay.ElementId.ID("ActivityScrollView").id;
}

fn applySemanticScroll(model: *const Model) void {
    const element_value = model.semantic_scroll_element_id orelse return;
    if (model.semantic_scroll_direction == 0 or !isScrollableSemanticId(element_value)) return;
    var element_id = clay.ElementId.ID("");
    element_id.id = element_value;
    const scroll = clay.getScrollContainerData(element_id);
    if (!scroll.found or !scroll.config.vertical) return;
    const max_scroll = @max(scroll.content_dimensions.h - scroll.scroll_container_dimensions.h, 0);
    const page = @max(scroll.scroll_container_dimensions.h * 0.8, 48);
    const delta = if (model.semantic_scroll_direction > 0) -page else page;
    scroll.scroll_position.y = @min(@max(scroll.scroll_position.y + delta, -max_scroll), 0);
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

fn permissionName(permission: @import("../platform/platform.zig").Permission) []const u8 {
    return switch (permission) {
        .camera => "相机",
        .microphone => "麦克风",
        .notifications => "通知",
        .media => "媒体",
    };
}

fn utf8Prefix(text: []const u8, max_bytes: usize) []const u8 {
    var length = @min(text.len, max_bytes);
    while (length > 0 and length < text.len and text[length] & 0xC0 == 0x80) length -= 1;
    return text[0..length];
}

fn formatFileMetadata(buffer: []u8, model: *const Model) []const u8 {
    if (model.file_read_pending or model.selectedFileUri().len == 0) return "";
    if (model.fileDisplayName().len == 0 and model.fileMimeType().len == 0 and !model.file_size_known) return "";

    const display_name = if (model.fileDisplayName().len > 0)
        utf8Prefix(model.fileDisplayName(), 160)
    else
        "未知";
    const mime_type = if (model.fileMimeType().len > 0)
        utf8Prefix(model.fileMimeType(), 96)
    else
        "未知";
    return if (model.file_size_known)
        std.fmt.bufPrint(
            buffer,
            "文件信息：名称 {s}｜类型 {s}｜大小 {d} 字节",
            .{ display_name, mime_type, model.file_size },
        ) catch "文件信息不可用"
    else
        std.fmt.bufPrint(
            buffer,
            "文件信息：名称 {s}｜类型 {s}｜大小未知",
            .{ display_name, mime_type },
        ) catch "文件信息不可用";
}

fn formatFilePreview(buffer: []u8, model: *const Model) []const u8 {
    if (model.file_read_pending) return "内容读取：正在读取…";
    if (model.file_read_error) |error_kind| return switch (error_kind) {
        .invalid_uri => "内容读取失败：URI 无效",
        .not_found => "内容读取失败：文件不存在",
        .permission_denied => "内容读取失败：没有读取权限",
        .io => "内容读取失败：I/O 错误",
        .unsupported => "内容读取失败：平台不支持",
    };
    if (model.selectedFileUri().len == 0) return "";

    const data = model.filePreview();
    const output = std.fmt.bufPrint(
        buffer,
        "内容预览（{d} 字节{s}）：",
        .{ data.len, if (model.file_preview_truncated) "，已截断" else "" },
    ) catch return "内容预览不可用";
    var length = output.len;
    if (data.len == 0) {
        const suffix = "空文件";
        if (length + suffix.len <= buffer.len) {
            @memcpy(buffer[length .. length + suffix.len], suffix);
            length += suffix.len;
        }
        return buffer[0..length];
    }

    if (std.unicode.utf8ValidateSlice(data)) {
        const preview = utf8Prefix(data, @min(data.len, 384));
        for (preview) |byte| {
            if (length == buffer.len) break;
            buffer[length] = if (byte < 0x20 or byte == 0x7f) ' ' else byte;
            length += 1;
        }
    } else {
        const hex = "0123456789ABCDEF";
        for (data[0..@min(data.len, 64)]) |byte| {
            if (length + 3 > buffer.len) break;
            buffer[length] = hex[byte >> 4];
            buffer[length + 1] = hex[byte & 0x0f];
            buffer[length + 2] = ' ';
            length += 3;
        }
    }
    return buffer[0..length];
}

fn formatFileStreamStatus(buffer: []u8, model: *const Model) []const u8 {
    if (model.file_stream_error) |error_kind| return switch (error_kind) {
        .invalid_uri => "完整读取失败：URI 无效",
        .not_found => "完整读取失败：文件不存在",
        .permission_denied => "完整读取失败：没有读取权限",
        .io => "完整读取失败：数据不连续或 I/O 错误",
        .unsupported => "完整读取失败：平台不支持",
    };
    if (model.file_stream_pending) {
        const phase = if (model.file_stream_cancel_pending) "正在取消" else "处理中";
        return if (model.file_size_known)
            std.fmt.bufPrint(
                buffer,
                "完整读取{s}：{d} / {d} 字节（{d} 块）",
                .{ phase, model.file_stream_bytes_consumed, model.file_size, model.file_stream_chunk_count },
            ) catch "完整读取状态不可用"
        else
            std.fmt.bufPrint(
                buffer,
                "完整读取{s}：{d} 字节（{d} 块）",
                .{ phase, model.file_stream_bytes_consumed, model.file_stream_chunk_count },
            ) catch "完整读取状态不可用";
    }
    if (model.file_stream_completed) return std.fmt.bufPrint(
        buffer,
        "完整读取完成：{d} 字节（{d} 块），FNV-1a {x}",
        .{ model.file_stream_bytes_consumed, model.file_stream_chunk_count, model.file_stream_hash },
    ) catch "完整读取状态不可用";
    if (model.file_stream_cancelled) return std.fmt.bufPrint(
        buffer,
        "完整读取已取消：已消费 {d} 字节（{d} 块）",
        .{ model.file_stream_bytes_consumed, model.file_stream_chunk_count },
    ) catch "完整读取状态不可用";
    return "";
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
    try std.testing.expect(result.semantic_nodes.len >= 10);
    var has_slider_semantics = false;
    var has_text_field_semantics = false;
    var has_text_semantics = false;
    var has_progress_semantics = false;
    var has_list_semantics = false;
    var has_forward_scroll_semantics = false;
    var has_tree_semantics = false;
    var has_expanded_tree_item = false;
    for (result.semantic_nodes) |node| {
        if (node.role == .slider and node.value != null) has_slider_semantics = true;
        if (node.role == .text_field and node.value_text.len == model.text().len) has_text_field_semantics = true;
        if (node.role == .text) has_text_semantics = true;
        if (node.role == .progress_bar and node.value != null) has_progress_semantics = true;
        if (node.role == .list) {
            has_list_semantics = true;
            if (node.scrollable and node.can_scroll_forward and !node.can_scroll_backward) {
                has_forward_scroll_semantics = true;
            }
        }
        if (node.role == .tree) has_tree_semantics = true;
        if (node.role == .tree_item and node.expanded != null) has_expanded_tree_item = true;
    }
    try std.testing.expect(has_slider_semantics);
    try std.testing.expect(has_text_field_semantics);
    try std.testing.expect(has_text_semantics);
    try std.testing.expect(has_progress_semantics);
    try std.testing.expect(has_list_semantics);
    try std.testing.expect(has_forward_scroll_semantics);
    try std.testing.expect(has_tree_semantics);
    try std.testing.expect(has_expanded_tree_item);

    model.semantic_scroll_element_id = clay.ElementId.ID("ActivityScrollView").id;
    model.semantic_scroll_direction = 1;
    const scrolled_frame = build(&model);
    const activity_scroll = clay.getScrollContainerData(clay.ElementId.ID("ActivityScrollView"));
    try std.testing.expect(activity_scroll.found);
    try std.testing.expect(activity_scroll.scroll_position.y < 0);
    var can_scroll_backward = false;
    for (scrolled_frame.semantic_nodes) |node| {
        if (node.element_id == clay.ElementId.ID("ActivityScrollView").id) {
            can_scroll_backward = node.can_scroll_backward;
            break;
        }
    }
    try std.testing.expect(can_scroll_backward);
    model.semantic_scroll_element_id = null;
    model.semantic_scroll_direction = 0;

    state.focus_state.focus(clay.ElementId.ID("PrimaryAction").id);
    const focused_frame = build(&model);
    var border_count: usize = 0;
    for (focused_frame.commands) |command| {
        if (command.command_type == .border) border_count += 1;
    }
    try std.testing.expect(border_count >= 1);

    model.text_submission_count = 1;
    const toast_frame = build(&model);
    var has_toast_command = false;
    var has_status_semantics = false;
    for (toast_frame.commands) |command| {
        if (command.z_index == 200 and command.command_type == .rectangle) {
            has_toast_command = true;
            break;
        }
    }
    for (toast_frame.semantic_nodes) |node| {
        if (node.role == .status) has_status_semantics = true;
    }
    try std.testing.expect(has_toast_command);
    try std.testing.expect(has_status_semantics);

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
    var has_modal_semantics = false;
    for (dialog_frame.semantic_nodes) |node| {
        if (node.role == .dialog and node.modal) {
            has_modal_semantics = true;
            break;
        }
    }

    try std.testing.expect(has_modal_command);
    try std.testing.expect(requested_close);
    try std.testing.expect(has_modal_semantics);
    try std.testing.expect(state.focus_state.modalOpen());
}

test "semantic actions reuse reducer-facing UI actions" {
    var model: Model = .{};

    var actions = handleSemanticAction(
        &model,
        clay.ElementId.ID("PrimaryAction").id,
        .activate,
        "",
    );
    try std.testing.expectEqual(@as(usize, 1), actions.len);
    try std.testing.expect(actions[0] == .primary_button_pressed);

    const expected_volume = model.demo_volume + 0.05;
    actions = handleSemanticAction(
        &model,
        clay.ElementId.ID("VolumeSlider").id,
        .increment,
        "",
    );
    try std.testing.expectEqual(expected_volume, actions[0].demo_volume_changed);

    actions = handleSemanticAction(
        &model,
        clay.ElementId.ID("DemoTextField").id,
        .set_text,
        "无障碍输入",
    );
    try std.testing.expectEqual(@as(usize, 3), actions.len);
    try std.testing.expect(actions[0] == .text_field_focus_changed);
    try std.testing.expect(actions[1] == .text_select_all);
    try std.testing.expectEqualStrings("无障碍输入", actions[2].text_inserted);

    actions = handleSemanticAction(
        &model,
        tree_view.itemId("ProjectTree", 0).id,
        .collapse,
        "",
    );
    try std.testing.expectEqual(@as(u8, 0), actions[0].demo_tree_toggled);

    actions = handleSemanticAction(
        &model,
        clay.ElementId.ID("ActivityScrollView").id,
        .scroll_forward,
        "",
    );
    try std.testing.expectEqual(@as(usize, 1), actions.len);
    try std.testing.expectEqual(
        clay.ElementId.ID("ActivityScrollView").id,
        actions[0].semantic_scroll_requested.element_id,
    );
    try std.testing.expectEqual(@as(i8, 1), actions[0].semantic_scroll_requested.direction);

    model.selected_file_uri_length = "content://sample".len;
    @memcpy(model.selected_file_uri_buffer[0..model.selected_file_uri_length], "content://sample");
    actions = handleSemanticAction(
        &model,
        clay.ElementId.ID("StreamSelectedFile").id,
        .activate,
        "",
    );
    try std.testing.expectEqual(@as(usize, 1), actions.len);
    try std.testing.expect(actions[0] == .platform_file_stream_requested);

    model.file_stream_pending = true;
    actions = handleSemanticAction(
        &model,
        clay.ElementId.ID("OpenFilePicker").id,
        .activate,
        "",
    );
    try std.testing.expectEqual(@as(usize, 0), actions.len);
}

test "file previews preserve UTF-8 text and format binary as hex" {
    var model: Model = .{};
    model.selected_file_uri_length = "content://sample".len;
    @memcpy(model.selected_file_uri_buffer[0..model.selected_file_uri_length], "content://sample");
    model.file_preview_length = "中文内容\nnext".len;
    @memcpy(model.file_preview_buffer[0..model.file_preview_length], "中文内容\nnext");
    var buffer: [768]u8 = undefined;
    const text_preview = formatFilePreview(&buffer, &model);
    try std.testing.expect(std.mem.indexOf(u8, text_preview, "中文内容 next") != null);

    model.file_preview_length = 4;
    @memcpy(model.file_preview_buffer[0..4], &[_]u8{ 0x89, 0x50, 0x4e, 0x47 });
    const binary_preview = formatFilePreview(&buffer, &model);
    try std.testing.expect(std.mem.indexOf(u8, binary_preview, "89 50 4E 47") != null);
}

test "file metadata formats name MIME type and exact size" {
    var model: Model = .{};
    model.selected_file_uri_length = "content://sample".len;
    @memcpy(model.selected_file_uri_buffer[0..model.selected_file_uri_length], "content://sample");
    model.file_display_name_length = "中文资料.txt".len;
    @memcpy(model.file_display_name_buffer[0..model.file_display_name_length], "中文资料.txt");
    model.file_mime_type_length = "text/plain".len;
    @memcpy(model.file_mime_type_buffer[0..model.file_mime_type_length], "text/plain");
    model.file_size = 74;
    model.file_size_known = true;

    var buffer: [512]u8 = undefined;
    const metadata = formatFileMetadata(&buffer, &model);
    try std.testing.expect(std.mem.indexOf(u8, metadata, "中文资料.txt") != null);
    try std.testing.expect(std.mem.indexOf(u8, metadata, "text/plain") != null);
    try std.testing.expect(std.mem.indexOf(u8, metadata, "74 字节") != null);
}

test "file stream status reports progress completion and digest" {
    var model: Model = .{
        .file_size = 8192,
        .file_size_known = true,
        .file_stream_pending = true,
        .file_stream_bytes_consumed = 4096,
        .file_stream_chunk_count = 1,
    };
    var buffer: [320]u8 = undefined;
    const progress = formatFileStreamStatus(&buffer, &model);
    try std.testing.expect(std.mem.indexOf(u8, progress, "4096 / 8192") != null);

    model.file_stream_pending = false;
    model.file_stream_completed = true;
    model.file_stream_hash = 0x1234;
    const completed = formatFileStreamStatus(&buffer, &model);
    try std.testing.expect(std.mem.indexOf(u8, completed, "FNV-1a 1234") != null);
}
