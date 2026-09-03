const std = @import("std");
const clay = @import("zclay");
const Action = @import("../app/action.zig").Action;
const Model = @import("../app/model.zig").Model;
const runtime_image = @import("../assets/runtime_image.zig");
const image_catalog = @import("../assets/image_catalog.zig");
const text_edit = @import("../app/text_edit.zig");
const font = @import("../text/font.zig");
const focus_manager = @import("focus_manager.zig");
const form_field = @import("widgets/form_field.zig");
const semantics = @import("semantics.zig");
const theme = @import("theme.zig");
const accordion = @import("widgets/accordion.zig");
const button = @import("widgets/button.zig");
const card = @import("widgets/card.zig");
const chip_group = @import("widgets/chip_group.zig");
const checkbox = @import("widgets/checkbox.zig");
const data_table = @import("widgets/data_table.zig");
const divider = @import("widgets/divider.zig");
const dialog = @import("widgets/dialog.zig");
const floating_window = @import("widgets/floating_window.zig");
const icon_button = @import("widgets/icon_button.zig");
const image_view = @import("widgets/image_view.zig");
const interaction = @import("widgets/interaction.zig");
const label = @import("widgets/label.zig");
const layer_layout = @import("widgets/layer_layout.zig");
const menu = @import("widgets/menu.zig");
const navigation_bar = @import("widgets/navigation_bar.zig");
const number_stepper = @import("widgets/number_stepper.zig");
const pagination = @import("widgets/pagination.zig");
const progress_bar = @import("widgets/progress_bar.zig");
const radio_group = @import("widgets/radio_group.zig");
const scroll_view = @import("widgets/scroll_view.zig");
const scroll_bar = @import("widgets/scroll_bar.zig");
const search_field = @import("widgets/search_field.zig");
const select = @import("widgets/select.zig");
const slider = @import("widgets/slider.zig");
const tabs = @import("widgets/tabs.zig");
const toast = @import("widgets/toast.zig");
const tree_view = @import("widgets/tree_view.zig");
const toggle_switch = @import("widgets/switch.zig");
const virtual_list = @import("widgets/virtual_list.zig");

const max_actions = 8;
const demo_virtual_list_item_count = 1000;
const demo_virtual_list_height: f32 = 240;
const demo_table_page_size = 6;
const demo_hero_source: image_view.Source = .{
    .resource = .demo_hero,
    .pixel_width = 128,
    .pixel_height = 64,
    .fit = .cover,
};
const activity_thumbnail_source: image_view.Source = .{
    .resource = .activity_thumbnail,
    .pixel_width = 96,
    .pixel_height = 64,
    .fit = .cover,
};

const demo_tree_items = [_]tree_view.Item{
    .{ .text = "zapp" },
    .{ .text = "src", .parent_index = 0 },
    .{ .text = "app", .parent_index = 1 },
    .{ .text = "ui", .parent_index = 1 },
    .{ .text = "render", .parent_index = 1 },
    .{ .text = "assets", .parent_index = 0 },
    .{ .text = "README.md", .parent_index = 0 },
};

const demo_density_items = [_]radio_group.Item{
    .{ .text = "紧凑" },
    .{ .text = "舒适" },
    .{ .text = "宽松" },
};

const image_cache_budget_items = [_]radio_group.Item{
    .{ .text = "1 槽" },
    .{ .text = "2 槽" },
    .{ .text = "3 槽" },
    .{ .text = "4 槽" },
};

const demo_filter_items = [_]chip_group.Item{
    .{ .text = "开发中" },
    .{ .text = "待复核" },
    .{ .text = "已完成" },
    .{ .text = "已归档", .disabled = true },
};

const demo_accordion_items = [_]accordion.Item{
    .{ .title = "账户与同步" },
    .{ .title = "通知设置" },
    .{ .title = "关于应用" },
};

const demo_sort_items = [_]select.Item{
    .{ .text = "最近更新" },
    .{ .text = "名称" },
    .{ .text = "大小" },
};

const demo_menu_items = [_]menu.Item{
    .{ .text = "打开详情" },
    .{ .text = "复制链接" },
    .{ .text = "删除（不可用）", .disabled = true },
};

const demo_tab_items = [_]tabs.Item{
    .{ .text = "概览" },
    .{ .text = "明细" },
    .{ .text = "日志" },
};

const demo_layers = [_]layer_layout.Layer{
    .{ .id = 0, .title = "Scene Layer" },
    .{ .id = 1, .title = "Inspector Layer" },
};

const demo_activity_items = [_][]const u8{
    "中文字体已通过 Fontstash 接入 Sokol",
    "Button 点击状态已接入 reducer",
    "Checkbox 设置已保存到 AppModel",
    "Switch 通知状态已更新",
    "ProgressBar 使用受控数值",
    "ScrollView 已启用垂直裁剪",
    "鼠标滚轮事件由 Sokol 转发",
    "触摸拖动由 Clay 管理",
};

const DemoTableRow = struct {
    code: []const u8,
    name: []const u8,
    status: []const u8,
    updated: []const u8,
};

const demo_table_rows = [_]DemoTableRow{
    .{ .code = "Z-104", .name = "中文字体", .status = "已完成", .updated = "09:42" },
    .{ .code = "Z-219", .name = "Android 桥", .status = "进行中", .updated = "10:18" },
    .{ .code = "Z-087", .name = "主题令牌", .status = "已完成", .updated = "昨天" },
    .{ .code = "Z-302", .name = "崩溃报告", .status = "待复核", .updated = "周一" },
    .{ .code = "Z-156", .name = "虚拟列表", .status = "已完成", .updated = "11:05" },
    .{ .code = "Z-241", .name = "数据表格", .status = "开发中", .updated = "刚刚" },
    .{ .code = "Z-318", .name = "分页控件", .status = "开发中", .updated = "刚刚" },
    .{ .code = "Z-336", .name = "文件预览", .status = "已完成", .updated = "周二" },
    .{ .code = "Z-351", .name = "输入法桥", .status = "待复核", .updated = "周二" },
    .{ .code = "Z-374", .name = "焦点导航", .status = "已完成", .updated = "周三" },
    .{ .code = "Z-402", .name = "权限请求", .status = "已完成", .updated = "周三" },
    .{ .code = "Z-419", .name = "发布签名", .status = "待配置", .updated = "周四" },
    .{ .code = "Z-437", .name = "性能基线", .status = "已完成", .updated = "周四" },
    .{ .code = "Z-458", .name = "菜单控件", .status = "已完成", .updated = "周五" },
    .{ .code = "Z-476", .name = "标签页", .status = "已完成", .updated = "周五" },
    .{ .code = "Z-493", .name = "单选控件", .status = "已完成", .updated = "周六" },
    .{ .code = "Z-507", .name = "选择控件", .status = "已完成", .updated = "周六" },
    .{ .code = "Z-524", .name = "真机验收", .status = "待进行", .updated = "下周" },
};

const DemoTableFilter = struct {
    order: [demo_table_rows.len]usize = undefined,
    count: usize = 0,

    fn items(self: *const DemoTableFilter) []const usize {
        return self.order[0..self.count];
    }
};

const state = struct {
    var memory: ?[]u8 = null;
    var interaction_state: interaction.State = .{};
    var focus_state: focus_manager.State = .{};
    var semantic_registry: semantics.Registry = .{};
    var toast_state: toast.State = .{};
    var data_table_state: data_table.State = .{};
    var pagination_state: pagination.State = .{};
    var number_stepper_state: number_stepper.State = .{};
    var virtual_list_state: virtual_list.State = .{};
    var floating_window_state: floating_window.State = .{
        .rect = .{ .x = 180, .y = 110, .width = 430, .height = 290 },
    };
    var layer_layout_state: layer_layout.State = .{};
    var scroll_bar_state: scroll_bar.State = .{};
    var nested_scroll_active = false;
    var nested_scroll_pointer_y: f32 = 0;
    var last_text_submission_count: u32 = 0;
    var last_auto_reveal_focus_id: ?u32 = null;
    var last_navigation_index: u8 = 0;
    var actions: [max_actions]Action = undefined;
    var action_count: usize = 0;
    var counter_text: [96]u8 = undefined;
    var confirmation_text: [96]u8 = undefined;
    var menu_status_text: [128]u8 = undefined;
    var search_status_text: [128]u8 = undefined;
    var virtual_list_status_text: [128]u8 = undefined;
    var permission_status_text: [160]u8 = undefined;
    var file_status_text: [256]u8 = undefined;
    var file_metadata_text: [512]u8 = undefined;
    var file_preview_text: [768]u8 = undefined;
    var file_stream_status_text: [320]u8 = undefined;
    var runtime_image_status_text: [320]u8 = undefined;
    var runtime_image_source: image_view.Source = .{
        .resource = .runtime_0,
        .pixel_width = 1,
        .pixel_height = 1,
        .fit = .contain,
    };
    var performance_frame_text: [192]u8 = undefined;
    var performance_cpu_text: [192]u8 = undefined;
    var crash_diagnostic_text: [320]u8 = undefined;
    var crash_build_id_text: [64]u8 = undefined;
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
    state.data_table_state = .{};
    state.pagination_state = .{};
    state.number_stepper_state = .{};
    state.virtual_list_state = .{};
    state.floating_window_state = .{
        .rect = .{ .x = 180, .y = 110, .width = 430, .height = 290 },
    };
    state.layer_layout_state = .{};
    state.scroll_bar_state = .{};
    state.nested_scroll_active = false;
    state.nested_scroll_pointer_y = 0;
    state.last_text_submission_count = model.application_name_input.submission_count;
    state.last_auto_reveal_focus_id = null;
    state.last_navigation_index = @min(model.demo_navigation_index, 2);
    state.action_count = 0;

    _ = clay.initialize(.init(memory), dimensions(model), .{
        .error_handler_function = clayError,
    });
    // Clay 0.14 may cull an offscreen clip-start while still emitting its
    // clip-end, producing an unbalanced render stream. Keep clip pairs intact;
    // large collections remain bounded by the project's virtual-list widgets.
    clay.setCullingEnabled(false);
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
    state.data_table_state = .{};
    state.pagination_state = .{};
    state.number_stepper_state = .{};
    state.virtual_list_state = .{};
    state.floating_window_state = .{
        .rect = .{ .x = 180, .y = 110, .width = 430, .height = 290 },
    };
    state.layer_layout_state = .{};
    state.scroll_bar_state = .{};
    state.nested_scroll_active = false;
    state.nested_scroll_pointer_y = 0;
    state.last_text_submission_count = 0;
    state.last_auto_reveal_focus_id = null;
    state.last_navigation_index = 0;
    state.action_count = 0;
}

/// Builds the responsive product shell and reports semantic UI actions.
pub fn build(model: *const Model) Frame {
    state.action_count = 0;
    if (state.memory == null) {
        state.semantic_registry.reset();
        return .{
            .clear_color = theme.dark.background,
            .commands = &.{},
            .actions = &.{},
            .semantic_nodes = &.{},
        };
    }

    clay.setLayoutDimensions(dimensions(model));
    clay.setPointerState(.{ .x = model.pointer_x, .y = model.pointer_y }, model.pointer_down);
    const pointer_input: interaction.Input = .{
        .x = model.pointer_x,
        .y = model.pointer_y,
        .down = model.pointer_down,
        .pressed = model.pointer_pressed,
        .released = model.pointer_released,
    };
    const floating_window_claims_pointer = model.demo_navigation_index == 0 and
        model.demo_floating_window_open and !model.demo_dialog_open and
        floating_window.claimsPointer(
            &state.floating_window_state,
            pointer_input,
            "DemoFloatingWindow",
        );
    const layer_layout_claims_pointer = model.demo_navigation_index == 0 and
        !model.demo_dialog_open and layer_layout.claimsPointer(
        &state.layer_layout_state,
        pointer_input,
        .{
            .id = "DemoLayerLayout",
            .layers = &demo_layers,
            .width = demoLayerLayoutWidth(model.viewport_width),
        },
    );
    const semantic_control_claims_pointer = previousSemanticControlClaimsPointer(model);
    const nested_scroll_before = beginNestedBoundaryScroll(model);
    const custom_drag_claimed = floating_window_claims_pointer or
        layer_layout_claims_pointer or semantic_control_claims_pointer or
        nested_scroll_before != null;
    const wheel_route = beginWheelScrollRoute(model);
    const scroll_bar_outer_target = virtualListScrollBarOuterTarget(model);
    applySemanticScroll(model);
    clay.updateScrollContainers(scroll_bar_outer_target == null and !custom_drag_claimed, .{
        .x = model.scroll_delta_x * 36,
        .y = model.scroll_delta_y * 36,
    }, @max(model.frame_delta_seconds, 1.0 / 240.0));
    if (wheel_route) |route| restoreWheelScrollRoute(route);
    if (scroll_bar_outer_target) |outer_y| restorePrimaryScrollPosition(outer_y);
    if (nested_scroll_before) |before| applyNestedCapturedScroll(before);
    if (model.pointer_released and !model.pointer_down) state.nested_scroll_active = false;
    const text_submission_changed =
        model.application_name_input.submission_count != state.last_text_submission_count;
    if (text_submission_changed) {
        state.last_text_submission_count = model.application_name_input.submission_count;
        state.toast_state.show(
            if (demoTextInvalid(model)) "请修正表单错误" else "表单已提交",
            2.5,
        );
    }
    state.toast_state.update(model.frame_delta_seconds);
    state.semantic_registry.reset();
    clay.beginLayout();

    const dialog_id = clay.ElementId.ID("DemoDialogPanel").id;
    const dialog_cancel_id = clay.ElementId.ID("DemoDialogCancel").id;
    const dialog_confirm_id = clay.ElementId.ID("DemoDialogConfirm").id;
    const primary_action_id = clay.ElementId.ID("PrimaryAction").id;
    const increment_progress_id = clay.ElementId.ID("IncrementProgress").id;
    const open_dialog_id = clay.ElementId.ID("OpenDemoDialog").id;
    const open_floating_window_id = clay.ElementId.ID("OpenFloatingWindow").id;
    const checkbox_id = clay.ElementId.ID("DemoCheckbox").id;
    const switch_id = clay.ElementId.ID("DemoSwitch").id;
    const sort_select_id = select.triggerId("SortSelect").id;
    const actions_menu_id = menu.triggerId("ActionsMenu").id;
    const virtual_list_index = virtual_list.boundedIndex(
        model.demo_virtual_list_selected_index,
        demo_virtual_list_item_count,
    ) orelse 0;
    const virtual_list_active_id = virtual_list.itemId("RecordsVirtualList", virtual_list_index).id;
    const filtered_table = demoTableFilteredOrder(
        model.demo_data_table_sort_column,
        model.demo_data_table_sort_descending,
        model.searchText(),
    );
    const table_order = filtered_table.items();
    const requested_selected_row = @min(@as(usize, model.demo_data_table_selected_row), demo_table_rows.len - 1);
    const selected_display_index = demoTableDisplayIndex(table_order, requested_selected_row);
    const table_selected_row = if (selected_display_index != null)
        requested_selected_row
    else if (table_order.len > 0)
        table_order[0]
    else
        0;
    const table_active_row_id = data_table.rowId("RecordsDataTable", table_selected_row).id;
    const table_page_count = pagination.pageCount(table_order.len, demo_table_page_size);
    const table_page = pagination.boundedPage(
        if (selected_display_index) |index| index / demo_table_page_size else 0,
        table_page_count,
    );
    const active_tab_index = tabs.boundedIndex(model.demo_tab_index, demo_tab_items.len) orelse 0;
    const active_tab_id = tabs.itemId("DataTabs", active_tab_index).id;
    const slider_id = clay.ElementId.ID("VolumeSlider").id;
    const retry_stepper_id = clay.ElementId.ID("RetryStepper").id;
    const search_field_id = clay.ElementId.ID("ProjectSearch").id;
    const search_clear_id = search_field.clearId("ProjectSearch").id;
    const text_field_id = clay.ElementId.ID("DemoTextField").id;
    const form_submit_id = clay.ElementId.ID("SubmitDemoForm").id;
    const permission_button_id = clay.ElementId.ID("RequestCameraPermission").id;
    const file_picker_button_id = clay.ElementId.ID("OpenFilePicker").id;
    const file_stream_button_id = clay.ElementId.ID("StreamSelectedFile").id;
    const runtime_image_button_id = clay.ElementId.ID("LoadRuntimeImage").id;
    const remote_image_url_id = clay.ElementId.ID("RemoteImageUrl").id;
    const remote_image_button_id = clay.ElementId.ID("LoadRemoteImage").id;
    const image_cache_clear_button_id = clay.ElementId.ID("ClearRuntimeImageCache").id;
    const crash_export_button_id = clay.ElementId.ID("ExportCrashReport").id;
    const active_navigation_index = @min(model.demo_navigation_index, 2);
    if (active_navigation_index != state.last_navigation_index) {
        state.last_navigation_index = active_navigation_index;
        state.focus_state.focus(clay.ElementId.IDI("MainNavigation", active_navigation_index).id);
    }
    if (model.demo_dialog_open) {
        state.focus_state.openModal(dialog_id, dialog_confirm_id);
        state.focus_state.setOrder(&.{ dialog_cancel_id, dialog_confirm_id });
    } else {
        state.focus_state.closeModal(dialog_id);
        var focus_order: [64]u32 = undefined;
        const navigation_order = [_]u32{
            clay.ElementId.IDI("MainNavigation", 0).id,
            clay.ElementId.IDI("MainNavigation", 1).id,
            clay.ElementId.IDI("MainNavigation", 2).id,
        };
        @memcpy(focus_order[0..navigation_order.len], &navigation_order);
        var focus_order_count = navigation_order.len;
        if (model.demo_navigation_index == 0) {
            if (model.last_native_crash != null) {
                focus_order[focus_order_count] = crash_export_button_id;
                focus_order_count += 1;
            }
            const primary_order = [_]u32{
                primary_action_id,
                increment_progress_id,
                open_dialog_id,
                open_floating_window_id,
            };
            @memcpy(focus_order[focus_order_count..][0..primary_order.len], &primary_order);
            focus_order_count += primary_order.len;
            if (model.demo_floating_window_open) {
                focus_order[focus_order_count] = floating_window.closeId("DemoFloatingWindow").id;
                focus_order_count += 1;
            }
            focus_order[focus_order_count] = active_tab_id;
            focus_order_count += 1;
            for (demo_tree_items, 0..) |_, tree_index| {
                if (tree_view.isVisible(&demo_tree_items, tree_index, model.demo_tree_expanded_mask)) {
                    focus_order[focus_order_count] = tree_view.itemId("ProjectTree", tree_index).id;
                    focus_order_count += 1;
                }
            }
            for (demo_accordion_items, 0..) |item, accordion_index| {
                if (!item.disabled) {
                    focus_order[focus_order_count] = accordion.headerId("SettingsAccordion", accordion_index).id;
                    focus_order_count += 1;
                }
            }
            const selection_order = [_]u32{ checkbox_id, switch_id };
            @memcpy(focus_order[focus_order_count..][0..selection_order.len], &selection_order);
            focus_order_count += selection_order.len;
            for (demo_density_items, 0..) |_, density_index| {
                focus_order[focus_order_count] = radio_group.itemId("DensityRadio", density_index).id;
                focus_order_count += 1;
            }
            for (demo_filter_items, 0..) |item, filter_index| {
                if (!item.disabled) {
                    focus_order[focus_order_count] = chip_group.itemId("StatusFilters", filter_index).id;
                    focus_order_count += 1;
                }
            }
            focus_order[focus_order_count] = sort_select_id;
            focus_order_count += 1;
            if (model.demo_sort_expanded) {
                for (demo_sort_items, 0..) |_, sort_index| {
                    focus_order[focus_order_count] = select.optionId("SortSelect", sort_index).id;
                    focus_order_count += 1;
                }
            } else if (state.focus_state.focused_id) |focused_id| {
                if (selectOptionIndex(focused_id) != null) state.focus_state.focus(sort_select_id);
            }
            focus_order[focus_order_count] = actions_menu_id;
            focus_order_count += 1;
            if (model.demo_menu_expanded) {
                for (demo_menu_items, 0..) |item, menu_index| {
                    if (!item.disabled) {
                        focus_order[focus_order_count] = menu.itemId("ActionsMenu", menu_index).id;
                        focus_order_count += 1;
                    }
                }
            } else if (state.focus_state.focused_id) |focused_id| {
                if (menuItemIndex(focused_id) != null) state.focus_state.focus(actions_menu_id);
            }
            focus_order[focus_order_count] = search_field_id;
            focus_order_count += 1;
            if (model.searchText().len > 0) {
                focus_order[focus_order_count] = search_clear_id;
                focus_order_count += 1;
            } else if (state.focus_state.isFocused(search_clear_id)) {
                state.focus_state.focus(search_field_id);
            }
            for (0..4) |column_index| {
                focus_order[focus_order_count] = data_table.headerId("RecordsDataTable", column_index).id;
                focus_order_count += 1;
            }
            if (table_order.len > 0) {
                focus_order[focus_order_count] = table_active_row_id;
                focus_order_count += 1;
                if (table_page > 0) {
                    focus_order[focus_order_count] = pagination.previousId("RecordsPagination").id;
                    focus_order_count += 1;
                }
                focus_order[focus_order_count] = pagination.pageId("RecordsPagination", table_page).id;
                focus_order_count += 1;
                if (table_page + 1 < table_page_count) {
                    focus_order[focus_order_count] = pagination.nextId("RecordsPagination").id;
                    focus_order_count += 1;
                }
            }
            focus_order[focus_order_count] = virtual_list_active_id;
            focus_order_count += 1;
            const trailing_order = [_]u32{
                slider_id,
                retry_stepper_id,
                text_field_id,
                form_submit_id,
                permission_button_id,
                file_picker_button_id,
                file_stream_button_id,
                runtime_image_button_id,
                remote_image_url_id,
                remote_image_button_id,
                image_cache_clear_button_id,
            };
            @memcpy(focus_order[focus_order_count..][0..trailing_order.len], &trailing_order);
            focus_order_count += trailing_order.len;
            if (state.focus_state.focused_id) |focused_id| {
                if (tabIndex(focused_id)) |focused_tab_index| {
                    if (focused_tab_index != active_tab_index) state.focus_state.focus(active_tab_id);
                }
                if (treeIndex(focused_id)) |focused_tree_index| {
                    if (tree_view.nearestVisibleAncestor(
                        &demo_tree_items,
                        focused_tree_index,
                        model.demo_tree_expanded_mask,
                    )) |visible_index| {
                        state.focus_state.focus(tree_view.itemId("ProjectTree", visible_index).id);
                    }
                }
                if (dataTableRowIndex(focused_id)) |focused_row_index| {
                    const page_start = table_page * demo_table_page_size;
                    const page_end = @min(page_start + demo_table_page_size, table_order.len);
                    if (demoTableDisplayIndex(table_order[page_start..page_end], focused_row_index) == null) {
                        state.focus_state.focus(if (table_order.len > 0) table_active_row_id else search_field_id);
                    }
                } else if (isPaginationElement(focused_id)) {
                    const pagination_focus_valid = table_order.len > 0 and
                        (if (paginationPageIndex(focused_id)) |focused_page|
                            focused_page < table_page_count
                        else if (focused_id == pagination.previousId("RecordsPagination").id)
                            table_page > 0
                        else
                            table_page + 1 < table_page_count);
                    if (!pagination_focus_valid) {
                        state.focus_state.focus(if (table_order.len > 0)
                            pagination.pageId("RecordsPagination", table_page).id
                        else
                            search_field_id);
                    }
                }
            }
        } else if (model.demo_navigation_index == 2) {
            for (demo_accordion_items, 0..) |item, accordion_index| {
                if (!item.disabled) {
                    focus_order[focus_order_count] = accordion.headerId("SettingsAccordion", accordion_index).id;
                    focus_order_count += 1;
                }
            }
            const settings_order = [_]u32{ checkbox_id, switch_id };
            @memcpy(focus_order[focus_order_count..][0..settings_order.len], &settings_order);
            focus_order_count += settings_order.len;
            for (demo_density_items, 0..) |_, density_index| {
                focus_order[focus_order_count] = radio_group.itemId("DensityRadio", density_index).id;
                focus_order_count += 1;
            }
            for (image_cache_budget_items, 0..) |_, budget_index| {
                focus_order[focus_order_count] = radio_group.itemId("ImageCacheBudgetRadio", budget_index).id;
                focus_order_count += 1;
            }
        }
        state.focus_state.setOrder(focus_order[0..focus_order_count]);
        if (state.focus_state.focused_id) |focused_id| {
            if (!state.focus_state.contains(focused_id)) {
                state.focus_state.focus(navigation_order[@min(@as(usize, model.demo_navigation_index), navigation_order.len - 1)]);
            }
        }
    }
    if (!model.demo_dialog_open) {
        if (table_page != @as(usize, model.demo_data_table_page)) {
            emit(.{ .demo_data_table_page_selected = @intCast(table_page) });
        }
        if (table_order.len > 0 and table_selected_row != requested_selected_row) {
            emit(.{ .demo_data_table_row_selected = @intCast(table_selected_row) });
        }
    }
    if (model.focus_next_requested) {
        _ = state.focus_state.move(1);
    } else if (model.focus_previous_requested) {
        _ = state.focus_state.move(-1);
    }
    if (!model.demo_dialog_open) {
        if (state.focus_state.focused_id) |focused_id| {
            const reveal_requested = state.last_auto_reveal_focus_id != focused_id or
                (focused_id == text_field_id and text_submission_changed);
            if (navigationIndex(focused_id) == null and reveal_requested) {
                const reveal_id = if (virtualListIndex(focused_id) != null)
                    clay.ElementId.ID("RecordsVirtualList").id
                else if (focused_id == text_field_id and demoTextInvalid(model))
                    form_field.containerId("DemoTextField").id
                else
                    focused_id;
                const page_scroll_id = if (model.demo_navigation_index == 2)
                    clay.ElementId.ID("SettingsPage").id
                else
                    clay.ElementId.ID("PrimaryCard").id;
                ensureElementVisibleInScrollContainer(reveal_id, page_scroll_id);
            }
            state.last_auto_reveal_focus_id = focused_id;
        } else {
            state.last_auto_reveal_focus_id = null;
        }
    }
    if (model.focus_next_requested or model.focus_previous_requested) {
        const focused_target = if (state.focus_state.focused_id) |focused_id|
            textTargetForElement(focused_id)
        else
            null;
        if (focused_target != model.active_text_input) {
            emit(.{ .text_input_focus_changed = focused_target });
        }
    }
    if (model.back_requested and model.active_text_input != null and !model.demo_dialog_open) {
        emit(.{ .text_input_focus_changed = null });
    }
    if (model.back_requested and model.demo_sort_expanded and !model.demo_dialog_open) {
        state.focus_state.focus(sort_select_id);
        emit(.{ .demo_sort_expanded = false });
    }
    if (model.back_requested and model.demo_menu_expanded and !model.demo_dialog_open) {
        state.focus_state.focus(actions_menu_id);
        emit(.{ .demo_menu_expanded = false });
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
        .up_pressed = model.focused_control_up_requested,
        .down_pressed = model.focused_control_down_requested,
        .left_pressed = model.focused_control_left_requested,
        .right_pressed = model.focused_control_right_requested,
        .home_pressed = model.focused_control_home_requested,
        .end_pressed = model.focused_control_end_requested,
    };
    var text_focus_requested = false;
    var text_blur_requested = false;
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
    const menu_status_text = std.fmt.bufPrint(
        &state.menu_status_text,
        "上次操作：{s} · {d} 次",
        .{
            switch (model.demo_menu_action_index) {
                1 => "复制链接",
                2 => "删除",
                else => "打开详情",
            },
            model.demo_menu_activation_count,
        },
    ) catch "菜单操作次数过多";
    const search_status_text = if (std.mem.trim(u8, model.searchText(), " \t\r\n").len == 0)
        std.fmt.bufPrint(&state.search_status_text, "共 {d} 个项目", .{table_order.len}) catch "项目数量不可用"
    else if (table_order.len == 0)
        "未找到匹配项目"
    else
        std.fmt.bufPrint(&state.search_status_text, "找到 {d} 个匹配项目", .{table_order.len}) catch "搜索结果数量不可用";
    const virtual_list_status_text = std.fmt.bufPrint(
        &state.virtual_list_status_text,
        "已选择第 {d} / {d} 条",
        .{ @as(usize, model.demo_virtual_list_selected_index) + 1, demo_virtual_list_item_count },
    ) catch "列表选择状态不可用";
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
    const runtime_image_status_text = formatRuntimeImageStatus(&state.runtime_image_status_text, model);
    const performance_frame_text = if (model.performance.sample_count == 0)
        "性能采样中…"
    else
        std.fmt.bufPrint(
            &state.performance_frame_text,
            "{d:.1} FPS · 平均 {d:.2} ms · P95 {d:.2} ms · 最慢 {d:.2} ms · 慢帧 {d:.1}%",
            .{
                model.performance.fps,
                model.performance.average_frame_ms,
                model.performance.p95_frame_ms,
                model.performance.slowest_frame_ms,
                model.performance.slow_frame_percent,
            },
        ) catch "帧性能数据不可用";
    const performance_cpu_text = if (model.performance.sample_count == 0)
        "正在建立 120 帧滚动窗口"
    else
        std.fmt.bufPrint(
            &state.performance_cpu_text,
            "UI {d:.2} ms · 渲染 {d:.2} ms · 总 CPU {d:.2} ms · 命令 {d}/{d} · 语义节点 {d}",
            .{
                model.performance.average_ui_cpu_ms,
                model.performance.average_render_cpu_ms,
                model.performance.average_total_cpu_ms,
                model.performance.average_command_count,
                model.performance.peak_command_count,
                model.performance.average_semantic_node_count,
            },
        ) catch "CPU 性能数据不可用";
    const crash_diagnostic_text = if (model.last_native_crash) |crash|
        if (crash.pc_in_app)
            std.fmt.bufPrint(
                &state.crash_diagnostic_text,
                "上次运行发生 native 崩溃：{s} ({d}) · {s} · libzapp+0x{x} · fault 0x{x} · tid {d}",
                .{
                    signalName(crash.signal_number),
                    crash.signal_number,
                    crashArchitectureName(crash.architecture),
                    crash.relative_pc,
                    crash.fault_address,
                    crash.thread_id,
                },
            ) catch "上次 native 崩溃记录过长"
        else
            std.fmt.bufPrint(
                &state.crash_diagnostic_text,
                "上次运行发生 native 崩溃：{s} ({d}) · {s} · PC 0x{x}（非 libzapp）· fault 0x{x} · tid {d}",
                .{
                    signalName(crash.signal_number),
                    crash.signal_number,
                    crashArchitectureName(crash.architecture),
                    crash.absolute_pc,
                    crash.fault_address,
                    crash.thread_id,
                },
            ) catch "上次 native 崩溃记录过长"
    else
        "崩溃诊断：本次启动未发现上次 native 致命信号记录";
    const crash_build_id_text = if (model.last_native_crash) |*crash|
        formatCrashBuildId(&state.crash_build_id_text, crash)
    else
        "";
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
                switch (@min(model.demo_navigation_index, 2)) {
                    0 => {
                        clay.UI()(card.declaration(.{
                            .id = "PrimaryCard",
                            .scroll_vertical = true,
                            .semantic_label = "控件示例",
                            .semantic_registry = &state.semantic_registry,
                        }))({
                            _ = state.semantic_registry.pushScrollAncestor(clay.ElementId.ID("PrimaryCard").id);
                            label.draw("Clay 应用框架", .{
                                .font_size = 22,
                                .semantic_id = .ID("PrimaryCardTitle"),
                                .semantic_registry = &state.semantic_registry,
                            });
                            image_view.draw(.{
                                .id = "DemoHeroImage",
                                .source = &demo_hero_source,
                                .width = control_width,
                                .height = 120,
                                .corner_radius = theme.controls.radius_medium,
                                .semantic_label = "蓝色渐变应用封面",
                                .semantic_registry = &state.semantic_registry,
                            });
                            label.draw("性能基线", .{
                                .font_size = 18,
                                .color = theme.controls.text_muted,
                                .semantic_id = .ID("PerformanceMetricsLabel"),
                                .semantic_registry = &state.semantic_registry,
                            });
                            label.draw(performance_frame_text, .{
                                .color = theme.controls.text_muted,
                                .wrap_mode = .words,
                            });
                            label.draw(performance_cpu_text, .{
                                .color = theme.controls.text_muted,
                                .wrap_mode = .words,
                            });
                            label.draw(crash_diagnostic_text, .{
                                .color = if (model.last_native_crash != null)
                                    .{ 255, 190, 120, 255 }
                                else
                                    theme.controls.text_muted,
                                .wrap_mode = .words,
                                .semantic_id = .ID("CrashDiagnosticsStatus"),
                                .semantic_registry = &state.semantic_registry,
                            });
                            if (crash_build_id_text.len > 0) label.draw(crash_build_id_text, .{
                                .color = .{ 255, 190, 120, 255 },
                                .semantic_id = .ID("CrashBuildIdStatus"),
                                .semantic_registry = &state.semantic_registry,
                            });
                            if (model.last_native_crash != null) {
                                if (button.draw(&state.interaction_state, input, .{
                                    .id = "ExportCrashReport",
                                    .text = if (model.crash_report_export_pending)
                                        "正在打开分享面板…"
                                    else
                                        "导出崩溃报告",
                                    .width = control_width,
                                    .disabled = modal_open or model.crash_report_export_pending,
                                    .focused = state.focus_state.isFocused(crash_export_button_id),
                                    .semantic_registry = &state.semantic_registry,
                                })) {
                                    state.focus_state.focus(crash_export_button_id);
                                    emit(.platform_crash_report_export_requested);
                                }
                                if (model.crash_report_export_pending) {
                                    label.draw("崩溃报告导出：正在打开系统分享面板…", .{
                                        .color = theme.controls.text_muted,
                                        .semantic_id = .ID("CrashReportExportStatus"),
                                        .semantic_registry = &state.semantic_registry,
                                    });
                                } else if (model.crash_report_export_attempted) {
                                    label.draw(
                                        if (model.crash_report_export_chooser_opened)
                                            "崩溃报告导出：已打开系统分享面板"
                                        else
                                            "崩溃报告导出：打开失败",
                                        .{
                                            .color = if (model.crash_report_export_chooser_opened)
                                                .{ 145, 205, 170, 255 }
                                            else
                                                .{ 255, 160, 145, 255 },
                                            .semantic_id = .ID("CrashReportExportStatus"),
                                            .semantic_registry = &state.semantic_registry,
                                        },
                                    );
                                }
                            }
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
                            if (button.draw(&state.interaction_state, input, .{
                                .id = "OpenFloatingWindow",
                                .text = if (model.demo_floating_window_open)
                                    "浮动窗口已打开"
                                else
                                    "打开浮动窗口",
                                .width = 200,
                                .disabled = modal_open or model.demo_floating_window_open,
                                .focused = state.focus_state.isFocused(open_floating_window_id),
                                .semantic_registry = &state.semantic_registry,
                            })) {
                                state.focus_state.focus(open_floating_window_id);
                                emit(.demo_floating_window_opened);
                            }
                            label.draw("可拖拽 Layer 布局", .{
                                .font_size = 18,
                                .color = theme.controls.text_muted,
                                .semantic_id = .ID("LayerLayoutLabel"),
                                .semantic_registry = &state.semantic_registry,
                            });
                            _ = layer_layout.draw(&state.layer_layout_state, input, .{
                                .id = "DemoLayerLayout",
                                .layers = &demo_layers,
                                .width = demoLayerLayoutWidth(model.viewport_width),
                                .height = 220,
                                .input_enabled = !modal_open,
                                .draw_layer = drawDemoLayer,
                                .semantic_registry = &state.semantic_registry,
                            });
                            label.draw("数据视图", .{
                                .font_size = 18,
                                .color = theme.controls.text_muted,
                                .semantic_id = .ID("DataTabsLabel"),
                                .semantic_registry = &state.semantic_registry,
                            });
                            const tabs_result = tabs.draw(&state.interaction_state, input, .{
                                .id = "DataTabs",
                                .items = &demo_tab_items,
                                .selected_index = model.demo_tab_index,
                                .item_width = if (narrow) control_width else 150,
                                .direction = control_direction,
                                .disabled = modal_open,
                                .focused_id = state.focus_state.focused_id,
                                .semantic_label = "数据视图",
                                .semantic_registry = &state.semantic_registry,
                            });
                            if (tabs_result.focus_index) |index| {
                                state.focus_state.focus(tabs.itemId("DataTabs", index).id);
                            }
                            if (tabs_result.selected_index) |index| {
                                state.focus_state.focus(tabs.itemId("DataTabs", index).id);
                                emit(.{ .demo_tab_selected = @intCast(index) });
                            }
                            label.draw(switch (model.demo_tab_index) {
                                1 => "当前页：明细",
                                2 => "当前页：日志",
                                else => "当前页：概览",
                            }, .{
                                .color = theme.controls.text_muted,
                                .semantic_id = .ID("DataTabsStatus"),
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
                            label.draw("设置分组", .{
                                .font_size = 18,
                                .color = theme.controls.text_muted,
                                .semantic_id = .ID("SettingsAccordionLabel"),
                                .semantic_registry = &state.semantic_registry,
                            });
                            const accordion_result = accordion.draw(&state.interaction_state, input, .{
                                .id = "SettingsAccordion",
                                .items = &demo_accordion_items,
                                .expanded_mask = model.demo_accordion_expanded_mask,
                                .mode = .single,
                                .width = control_width,
                                .disabled = modal_open,
                                .focused_id = state.focus_state.focused_id,
                                .semantic_label = "应用设置分组",
                                .semantic_registry = &state.semantic_registry,
                                .draw_panel = drawDemoAccordionPanel,
                                .panel_context = @ptrCast(&state.semantic_registry),
                            });
                            if (accordion_result.focus_index) |index| {
                                state.focus_state.focus(accordion.headerId("SettingsAccordion", index).id);
                            }
                            if (accordion_result.expanded_mask) |mask| {
                                emit(.{ .demo_accordion_expanded = mask });
                            }
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
                            label.draw("界面密度", .{
                                .color = theme.controls.text_muted,
                                .semantic_id = .ID("DensityRadioLabel"),
                                .semantic_registry = &state.semantic_registry,
                            });
                            const radio_result = radio_group.draw(&state.interaction_state, input, .{
                                .id = "DensityRadio",
                                .items = &demo_density_items,
                                .selected_index = model.demo_density_index,
                                .item_width = if (narrow) control_width else 150,
                                .direction = control_direction,
                                .disabled = modal_open,
                                .focused_id = state.focus_state.focused_id,
                                .semantic_label = "界面密度",
                                .semantic_registry = &state.semantic_registry,
                            });
                            if (radio_result.focus_index) |index| {
                                state.focus_state.focus(radio_group.itemId("DensityRadio", index).id);
                            }
                            if (radio_result.selected_index) |index| {
                                state.focus_state.focus(radio_group.itemId("DensityRadio", index).id);
                                emit(.{ .demo_density_selected = @intCast(index) });
                            }
                            label.draw("状态筛选", .{
                                .color = theme.controls.text_muted,
                                .semantic_id = .ID("StatusFiltersLabel"),
                                .semantic_registry = &state.semantic_registry,
                            });
                            const filter_result = chip_group.draw(&state.interaction_state, input, .{
                                .id = "StatusFilters",
                                .items = &demo_filter_items,
                                .selected_mask = model.demo_filter_mask,
                                .direction = control_direction,
                                .focused_id = state.focus_state.focused_id,
                                .disabled = modal_open,
                                .semantic_label = "状态筛选",
                                .semantic_registry = &state.semantic_registry,
                            });
                            if (filter_result.focus_index) |index| {
                                state.focus_state.focus(chip_group.itemId("StatusFilters", index).id);
                            }
                            if (filter_result.toggled_index) |index| {
                                state.focus_state.focus(chip_group.itemId("StatusFilters", index).id);
                                emit(.{ .demo_filter_toggled = @intCast(index) });
                            }
                            label.draw("内容排序", .{
                                .color = theme.controls.text_muted,
                                .semantic_id = .ID("SortSelectLabel"),
                                .semantic_registry = &state.semantic_registry,
                            });
                            const select_result = select.draw(&state.interaction_state, input, .{
                                .id = "SortSelect",
                                .items = &demo_sort_items,
                                .selected_index = model.demo_sort_index,
                                .expanded = model.demo_sort_expanded,
                                .width = control_width,
                                .disabled = modal_open,
                                .focused_id = state.focus_state.focused_id,
                                .semantic_label = "内容排序",
                                .semantic_registry = &state.semantic_registry,
                            });
                            if (select_result.focus_id) |focus_id| state.focus_state.focus(focus_id);
                            if (select_result.selected_index) |index| {
                                emit(.{ .demo_sort_selected = @intCast(index) });
                            }
                            if (select_result.expanded) |expanded| {
                                if (expanded != model.demo_sort_expanded) {
                                    emit(.{ .demo_sort_expanded = expanded });
                                }
                            }
                            label.draw("操作菜单", .{
                                .color = theme.controls.text_muted,
                                .semantic_id = .ID("ActionsMenuLabel"),
                                .semantic_registry = &state.semantic_registry,
                            });
                            const menu_result = menu.draw(&state.interaction_state, input, .{
                                .id = "ActionsMenu",
                                .text = "更多操作",
                                .items = &demo_menu_items,
                                .expanded = model.demo_menu_expanded,
                                .width = control_width,
                                .disabled = modal_open,
                                .focused_id = state.focus_state.focused_id,
                                .semantic_label = "更多操作",
                                .semantic_registry = &state.semantic_registry,
                            });
                            if (menu_result.focus_id) |focus_id| state.focus_state.focus(focus_id);
                            if (menu_result.activated_index) |index| {
                                emit(.{ .demo_menu_item_activated = @intCast(index) });
                            }
                            if (menu_result.expanded) |expanded| {
                                if (expanded != model.demo_menu_expanded) {
                                    emit(.{ .demo_menu_expanded = expanded });
                                }
                            }
                            label.draw(menu_status_text, .{
                                .color = theme.controls.text_muted,
                                .semantic_id = .ID("ActionsMenuStatus"),
                                .semantic_registry = &state.semantic_registry,
                            });
                            label.draw("项目搜索", .{
                                .color = theme.controls.text_muted,
                                .semantic_id = .ID("ProjectSearchLabel"),
                                .semantic_registry = &state.semantic_registry,
                            });
                            const search_result = search_field.draw(&state.interaction_state, input, .{
                                .id = "ProjectSearch",
                                .text = model.searchText(),
                                .placeholder = "搜索项目、状态或日志",
                                .cursor = model.search_input.cursor,
                                .selection_anchor = model.search_input.selection_anchor,
                                .composition = model.search_input.composition(),
                                .width = control_width,
                                .focused = model.isTextInputActive(.search),
                                .clear_focused = state.focus_state.isFocused(search_clear_id),
                                .disabled = modal_open,
                                .semantic_label = "项目搜索",
                                .semantic_registry = &state.semantic_registry,
                            });
                            if (search_result.text.focus_requested) {
                                state.focus_state.focus(search_field_id);
                                text_focus_requested = true;
                                if (!model.isTextInputActive(.search)) {
                                    emit(.{ .text_input_focus_changed = .search });
                                }
                            }
                            if (search_result.text.blur_requested) text_blur_requested = true;
                            if (search_result.text.cursor_position) |position| {
                                emit(.{ .text_cursor_set = .{
                                    .position = position,
                                    .selecting = search_result.text.selecting,
                                } });
                            }
                            if (search_result.clear_requested) {
                                state.focus_state.focus(search_field_id);
                                text_focus_requested = true;
                                if (!model.isTextInputActive(.search)) {
                                    emit(.{ .text_input_focus_changed = .search });
                                }
                                emit(.{ .text_cleared = .search });
                            }
                            label.draw(search_status_text, .{
                                .font_size = 13,
                                .color = theme.controls.text_muted,
                                .semantic_id = .ID("ProjectSearchStatus"),
                                .semantic_role = .status,
                                .semantic_registry = &state.semantic_registry,
                            });
                            label.draw("数据表格", .{
                                .color = theme.controls.text_muted,
                                .semantic_id = .ID("RecordsDataTableLabel"),
                                .semantic_registry = &state.semantic_registry,
                            });
                            const table_columns = [_]data_table.Column{
                                .{ .label = "编号", .width = control_width * 0.20 },
                                .{ .label = "名称", .width = control_width * 0.34 },
                                .{ .label = "状态", .width = control_width * 0.25 },
                                .{ .label = "更新", .width = control_width * 0.21 },
                            };
                            const table_page_start = table_page * demo_table_page_size;
                            const table_page_end = @min(table_page_start + demo_table_page_size, table_order.len);
                            const table_page_order = table_order[table_page_start..table_page_end];
                            const table_result = data_table.draw(
                                &state.data_table_state,
                                &state.interaction_state,
                                input,
                                .{
                                    .id = "RecordsDataTable",
                                    .columns = &table_columns,
                                    .row_count = table_page_order.len,
                                    .row_order = table_page_order,
                                    .selected_row_index = model.demo_data_table_selected_row,
                                    .sort_column_index = model.demo_data_table_sort_column,
                                    .sort_direction = if (model.demo_data_table_sort_descending) .descending else .ascending,
                                    .format_cell = formatDemoTableCell,
                                    .width = control_width,
                                    .disabled = modal_open,
                                    .focused_id = state.focus_state.focused_id,
                                    .semantic_label = "项目数据",
                                    .semantic_registry = &state.semantic_registry,
                                },
                            );
                            if (table_result.focus_id) |focus_id| state.focus_state.focus(focus_id);
                            if (table_result.selected_row_index) |row_index| {
                                emit(.{ .demo_data_table_row_selected = @intCast(row_index) });
                            }
                            if (table_result.sort_request) |sort_request| {
                                const descending = sort_request.direction == .descending;
                                emit(.{ .demo_data_table_sorted = .{
                                    .column_index = @intCast(sort_request.column_index),
                                    .descending = descending,
                                } });
                                const sorted_filtered = demoTableFilteredOrder(
                                    sort_request.column_index,
                                    descending,
                                    model.searchText(),
                                );
                                const selected_page = demoTablePageForRow(sorted_filtered.items(), table_selected_row);
                                if (selected_page != table_page) {
                                    emit(.{ .demo_data_table_page_selected = @intCast(selected_page) });
                                }
                            }
                            if (table_order.len > 0) {
                                const pagination_result = pagination.draw(
                                    &state.pagination_state,
                                    &state.interaction_state,
                                    input,
                                    .{
                                        .id = "RecordsPagination",
                                        .total_items = table_order.len,
                                        .page_size = demo_table_page_size,
                                        .current_page = table_page,
                                        .disabled = modal_open,
                                        .focused_id = state.focus_state.focused_id,
                                        .semantic_label = "项目数据分页",
                                        .semantic_registry = &state.semantic_registry,
                                    },
                                );
                                if (pagination_result.focus_id) |focus_id| state.focus_state.focus(focus_id);
                                if (pagination_result.selected_page) |selected_page| {
                                    emit(.{ .demo_data_table_page_selected = @intCast(selected_page) });
                                    const first_row = table_order[selected_page * demo_table_page_size];
                                    emit(.{ .demo_data_table_row_selected = @intCast(first_row) });
                                }
                            }
                            label.draw("虚拟列表（1000 条）", .{
                                .color = theme.controls.text_muted,
                                .semantic_id = .ID("RecordsVirtualListLabel"),
                                .semantic_registry = &state.semantic_registry,
                            });
                            const virtual_list_result = virtual_list.draw(
                                &state.virtual_list_state,
                                &state.interaction_state,
                                input,
                                .{
                                    .id = "RecordsVirtualList",
                                    .item_count = demo_virtual_list_item_count,
                                    .selected_index = model.demo_virtual_list_selected_index,
                                    .format_item = formatVirtualListItem,
                                    .width = control_width,
                                    .height = demo_virtual_list_height,
                                    .disabled = modal_open,
                                    .focused_id = state.focus_state.focused_id,
                                    .semantic_label = "数据记录",
                                    .semantic_registry = &state.semantic_registry,
                                },
                            );
                            if (virtual_list_result.focus_index) |index| {
                                state.focus_state.focus(virtual_list.itemId("RecordsVirtualList", index).id);
                            }
                            if (virtual_list_result.selected_index) |index| {
                                emit(.{ .demo_virtual_list_selected = @intCast(index) });
                            }
                            label.draw(virtual_list_status_text, .{
                                .color = theme.controls.text_muted,
                                .semantic_id = .ID("RecordsVirtualListStatus"),
                                .semantic_registry = &state.semantic_registry,
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
                            label.draw("重试次数", .{
                                .color = theme.controls.text_muted,
                                .semantic_id = .ID("RetryStepperLabel"),
                                .semantic_registry = &state.semantic_registry,
                            });
                            if (number_stepper.draw(
                                &state.number_stepper_state,
                                &state.interaction_state,
                                input,
                                .{
                                    .id = "RetryStepper",
                                    .value = model.demo_retry_count,
                                    .min = 0,
                                    .max = 10,
                                    .step = 1,
                                    .width = control_width,
                                    .disabled = modal_open,
                                    .focused = state.focus_state.isFocused(retry_stepper_id),
                                    .semantic_label = "重试次数",
                                    .semantic_registry = &state.semantic_registry,
                                },
                            )) |value| {
                                state.focus_state.focus(retry_stepper_id);
                                emit(.{ .demo_retry_count_changed = value });
                            }
                            label.draw("表单字段", .{
                                .font_size = 18,
                                .color = theme.controls.text_muted,
                                .semantic_id = .ID("FormFieldSectionLabel"),
                                .semantic_registry = &state.semantic_registry,
                            });
                            const text_result = form_field.draw(&state.interaction_state, input, .{
                                .id = "DemoTextField",
                                .label_text = "应用名称",
                                .text = model.text(),
                                .placeholder = "例如：我的 ZAPP",
                                .cursor = model.application_name_input.cursor,
                                .selection_anchor = model.application_name_input.selection_anchor,
                                .composition = model.textComposition(),
                                .helper_text = "至少输入 2 个字符，按 Enter 提交",
                                .error_message = "应用名称至少需要 2 个字符",
                                .width = control_width,
                                .focused = model.isTextInputActive(.application_name),
                                .disabled = modal_open,
                                .required = true,
                                .invalid = demoTextInvalid(model),
                                .semantic_registry = &state.semantic_registry,
                            });
                            if (text_result.focus_requested) {
                                state.focus_state.focus(text_field_id);
                                text_focus_requested = true;
                                if (!model.isTextInputActive(.application_name)) {
                                    emit(.{ .text_input_focus_changed = .application_name });
                                }
                            }
                            if (text_result.blur_requested) text_blur_requested = true;
                            if (text_result.cursor_position) |position| {
                                emit(.{ .text_cursor_set = .{
                                    .position = position,
                                    .selecting = text_result.selecting,
                                } });
                            }
                            if (button.draw(&state.interaction_state, input, .{
                                .id = "SubmitDemoForm",
                                .text = "提交表单",
                                .width = control_width,
                                .disabled = modal_open,
                                .focused = state.focus_state.isFocused(form_submit_id),
                                .semantic_registry = &state.semantic_registry,
                            })) {
                                state.focus_state.focus(form_submit_id);
                                emit(.text_submitted);
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
                                    .disabled = modal_open or model.file_picker_pending or model.file_stream_pending or
                                        model.runtime_image_load_pending,
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
                                        model.file_read_pending or model.file_stream_cancel_pending or
                                        model.runtime_image_load_pending,
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
                            const remote_url_result = form_field.draw(&state.interaction_state, input, .{
                                .id = "RemoteImageUrl",
                                .label_text = "远程图片 URL",
                                .text = model.remoteImageUrl(),
                                .placeholder = "https://example.com/image.png",
                                .cursor = model.remote_image_url_input.cursor,
                                .selection_anchor = model.remote_image_url_input.selection_anchor,
                                .composition = model.remote_image_url_input.composition(),
                                .helper_text = "仅接受 HTTPS 的 PNG 或 JPEG，最大 16 MiB",
                                .width = control_width,
                                .focused = model.isTextInputActive(.remote_image_url),
                                .disabled = modal_open or model.runtime_image_load_pending,
                                .semantic_registry = &state.semantic_registry,
                            });
                            if (remote_url_result.focus_requested) {
                                state.focus_state.focus(remote_image_url_id);
                                text_focus_requested = true;
                                if (!model.isTextInputActive(.remote_image_url)) {
                                    emit(.{ .text_input_focus_changed = .remote_image_url });
                                }
                            }
                            if (remote_url_result.blur_requested) text_blur_requested = true;
                            if (remote_url_result.cursor_position) |position| {
                                emit(.{ .text_cursor_set = .{
                                    .position = position,
                                    .selecting = remote_url_result.selecting,
                                } });
                            }
                            if (button.draw(&state.interaction_state, input, .{
                                .id = "LoadRemoteImage",
                                .text = if (model.runtime_image_cancel_pending and model.runtime_image_source_remote)
                                    "正在取消远程图片…"
                                else if (model.runtime_image_load_pending and model.runtime_image_source_remote)
                                    "取消远程图片加载"
                                else
                                    "加载远程图片",
                                .width = control_width,
                                .disabled = modal_open or model.remoteImageUrl().len == 0 or
                                    model.runtime_image_cancel_pending or
                                    (model.runtime_image_load_pending and !model.runtime_image_source_remote),
                                .focused = state.focus_state.isFocused(remote_image_button_id),
                                .semantic_registry = &state.semantic_registry,
                            })) {
                                state.focus_state.focus(remote_image_button_id);
                                emit(if (model.runtime_image_load_pending and model.runtime_image_source_remote)
                                    .platform_remote_image_load_cancel_requested
                                else
                                    .platform_remote_image_load_requested);
                            }
                            if (button.draw(&state.interaction_state, input, .{
                                .id = "LoadRuntimeImage",
                                .text = if (model.runtime_image_cancel_pending)
                                    "取消图片加载中…"
                                else if (model.runtime_image_load_pending)
                                    "取消图片加载"
                                else if (model.runtime_image_loaded)
                                    "重新加载所选图片"
                                else
                                    "加载所选图片",
                                .width = control_width,
                                .disabled = modal_open or model.selectedFileUri().len == 0 or
                                    model.file_read_pending or model.file_stream_pending or
                                    model.runtime_image_cancel_pending or runtimeImageTooLarge(model) or
                                    (model.runtime_image_load_pending and model.runtime_image_source_remote),
                                .focused = state.focus_state.isFocused(runtime_image_button_id),
                                .semantic_registry = &state.semantic_registry,
                            })) {
                                state.focus_state.focus(runtime_image_button_id);
                                emit(if (model.runtime_image_load_pending and !model.runtime_image_source_remote)
                                    .platform_runtime_image_load_cancel_requested
                                else
                                    .platform_runtime_image_load_requested);
                            }
                            if (button.draw(&state.interaction_state, input, .{
                                .id = "ClearRuntimeImageCache",
                                .text = if (model.runtime_image_cache_clear_requested)
                                    "正在清空图片缓存…"
                                else
                                    "清空图片缓存",
                                .width = control_width,
                                .disabled = modal_open or model.runtime_image_cached_count == 0 or
                                    model.runtime_image_load_pending or
                                    model.runtime_image_cache_clear_requested,
                                .focused = state.focus_state.isFocused(image_cache_clear_button_id),
                                .semantic_registry = &state.semantic_registry,
                            })) {
                                state.focus_state.focus(image_cache_clear_button_id);
                                emit(.{ .runtime_image_cache_clear_requested = .manual });
                            }
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
                            if (runtime_image_status_text.len > 0) label.draw(runtime_image_status_text, .{
                                .color = theme.controls.text_muted,
                                .wrap_mode = .words,
                                .semantic_id = .ID("RuntimeImageStatus"),
                                .semantic_registry = &state.semantic_registry,
                            });
                            if (model.runtime_image_loaded) {
                                state.runtime_image_source.resource = model.runtime_image_resource;
                                state.runtime_image_source.pixel_width = @floatFromInt(model.runtime_image_width);
                                state.runtime_image_source.pixel_height = @floatFromInt(model.runtime_image_height);
                                image_view.draw(.{
                                    .id = "RuntimeImagePreview",
                                    .source = &state.runtime_image_source,
                                    .width = if (compact) 220 else 320,
                                    .height = 180,
                                    .corner_radius = theme.controls.radius_medium,
                                    .semantic_label = "所选文件图片预览",
                                    .semantic_registry = &state.semantic_registry,
                                });
                            }
                            label.draw(confirmation_text, .{
                                .color = .{ 145, 171, 207, 255 },
                                .semantic_id = .ID("DialogConfirmationCount"),
                                .semantic_registry = &state.semantic_registry,
                            });
                            state.semantic_registry.popScrollAncestor();
                            scroll_bar.draw(&state.scroll_bar_state, input, .{
                                .id = "PrimaryCardScrollBar",
                                .scroll_id = "PrimaryCard",
                            });
                        });

                        clay.UI()(scroll_view.declaration(.{
                            .id = "ActivityScrollView",
                            .height = if (compact) 112 else 144,
                            .background_color = .{ 24, 56, 70, 255 },
                            .semantic_label = "最近活动",
                            .semantic_registry = &state.semantic_registry,
                        }))({
                            _ = state.semantic_registry.pushScrollAncestor(clay.ElementId.ID("ActivityScrollView").id);
                            label.draw("最近活动", .{
                                .font_size = 18,
                                .color = .{ 155, 211, 207, 255 },
                                .semantic_id = .ID("ActivityTitle"),
                                .semantic_registry = &state.semantic_registry,
                            });
                            inline for (demo_activity_items, 0..) |activity, activity_index| {
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
                            state.semantic_registry.popScrollAncestor();
                            scroll_bar.draw(&state.scroll_bar_state, input, .{
                                .id = "ActivityScrollBar",
                                .scroll_id = "ActivityScrollView",
                                .width = 10,
                                .min_thumb_height = 24,
                            });
                        });
                    },
                    1 => drawActivityPage(compact, input),
                    else => drawSettingsPage(model, input, control_width, control_direction, narrow, modal_open),
                }
            });
        });
    });

    if (model.demo_floating_window_open) {
        const floating_result = floating_window.draw(&state.floating_window_state, input, .{
            .id = "DemoFloatingWindow",
            .title = "Floating Window",
            .viewport_width = @floatFromInt(@max(model.viewport_width, 1)),
            .viewport_height = @floatFromInt(@max(model.viewport_height, 1)),
            .input_enabled = !model.demo_dialog_open,
            .focused_id = state.focus_state.focused_id,
            .draw_content = drawDemoFloatingWindowContent,
            .semantic_registry = &state.semantic_registry,
        });
        if (floating_result.close_focus_requested) {
            state.focus_state.focus(floating_window.closeId("DemoFloatingWindow").id);
        }
        if (floating_result.close_requested) emit(.demo_floating_window_closed);
    }

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

    if (text_blur_requested and !text_focus_requested and model.active_text_input != null) {
        emit(.{ .text_input_focus_changed = null });
    }

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
    const floating_window_open_id = clay.ElementId.ID("OpenFloatingWindow").id;
    const floating_window_close_id = floating_window.closeId("DemoFloatingWindow").id;
    const checkbox_id = clay.ElementId.ID("DemoCheckbox").id;
    const switch_id = clay.ElementId.ID("DemoSwitch").id;
    const sort_select_id = select.triggerId("SortSelect").id;
    const actions_menu_id = menu.triggerId("ActionsMenu").id;
    const slider_id = clay.ElementId.ID("VolumeSlider").id;
    const retry_stepper_id = clay.ElementId.ID("RetryStepper").id;
    const search_field_id = clay.ElementId.ID("ProjectSearch").id;
    const search_clear_id = search_field.clearId("ProjectSearch").id;
    const text_field_id = clay.ElementId.ID("DemoTextField").id;
    const form_submit_id = clay.ElementId.ID("SubmitDemoForm").id;
    const permission_id = clay.ElementId.ID("RequestCameraPermission").id;
    const file_picker_id = clay.ElementId.ID("OpenFilePicker").id;
    const file_stream_id = clay.ElementId.ID("StreamSelectedFile").id;
    const runtime_image_id = clay.ElementId.ID("LoadRuntimeImage").id;
    const remote_image_url_id = clay.ElementId.ID("RemoteImageUrl").id;
    const remote_image_id = clay.ElementId.ID("LoadRemoteImage").id;
    const image_cache_clear_id = clay.ElementId.ID("ClearRuntimeImageCache").id;
    const crash_export_id = clay.ElementId.ID("ExportCrashReport").id;
    const dialog_cancel_id = clay.ElementId.ID("DemoDialogCancel").id;
    const dialog_confirm_id = clay.ElementId.ID("DemoDialogConfirm").id;

    if (model.demo_dialog_open and element_id != dialog_cancel_id and element_id != dialog_confirm_id) {
        return state.actions[0..0];
    }

    switch (semantic_action) {
        .focus => {
            if (isInteractiveSemanticId(element_id)) {
                state.focus_state.focus(element_id);
                const target = textTargetForElement(element_id);
                if (model.active_text_input != target) {
                    emit(.{ .text_input_focus_changed = target });
                }
            }
        },
        .activate => {
            if (menuItemIndex(element_id)) |index| {
                if (demo_menu_items[index].disabled) return state.actions[0..0];
            }
            state.focus_state.focus(element_id);
            if (model.active_text_input != null and textTargetForElement(element_id) == null and
                element_id != search_clear_id)
            {
                emit(.{ .text_input_focus_changed = null });
            }
            if (element_id == primary_id) emit(.primary_button_pressed) else if (element_id == progress_id) emit(.demo_progress_incremented) else if (element_id == dialog_open_id) emit(.demo_dialog_opened) else if (element_id == floating_window_open_id) emit(.demo_floating_window_opened) else if (element_id == floating_window_close_id) emit(.demo_floating_window_closed) else if (element_id == checkbox_id) emit(.demo_checkbox_toggled) else if (element_id == switch_id) emit(.demo_switch_toggled) else if (element_id == text_field_id) {
                if (!model.isTextInputActive(.application_name)) emit(.{ .text_input_focus_changed = .application_name });
            } else if (element_id == search_field_id) {
                if (!model.isTextInputActive(.search)) emit(.{ .text_input_focus_changed = .search });
            } else if (element_id == search_clear_id) {
                state.focus_state.focus(search_field_id);
                emit(.{ .text_input_focus_changed = .search });
                emit(.{ .text_cleared = .search });
            } else if (element_id == form_submit_id) emit(.text_submitted) else if (element_id == permission_id) emit(.{ .platform_permission_requested = .camera }) else if (element_id == file_picker_id) {
                if (!model.file_picker_pending and !model.file_stream_pending and
                    !model.runtime_image_load_pending)
                {
                    emit(.platform_file_picker_requested);
                }
            } else if (element_id == file_stream_id) {
                if (model.file_stream_pending and !model.file_stream_cancel_pending) {
                    emit(.platform_file_stream_cancel_requested);
                } else if (!model.file_stream_pending and !model.file_read_pending and model.selectedFileUri().len > 0) {
                    emit(.platform_file_stream_requested);
                }
            } else if (element_id == runtime_image_id) {
                if (model.runtime_image_load_pending and !model.runtime_image_source_remote and
                    !model.runtime_image_cancel_pending)
                {
                    emit(.platform_runtime_image_load_cancel_requested);
                } else if (!model.runtime_image_load_pending and !model.file_stream_pending and
                    !model.file_read_pending and model.selectedFileUri().len > 0 and
                    !runtimeImageTooLarge(model))
                {
                    emit(.platform_runtime_image_load_requested);
                }
            } else if (element_id == remote_image_url_id) {
                if (!model.isTextInputActive(.remote_image_url))
                    emit(.{ .text_input_focus_changed = .remote_image_url });
            } else if (element_id == remote_image_id) {
                if (model.runtime_image_load_pending and model.runtime_image_source_remote and
                    !model.runtime_image_cancel_pending)
                {
                    emit(.platform_remote_image_load_cancel_requested);
                } else if (!model.runtime_image_load_pending and model.remoteImageUrl().len > 0) {
                    emit(.platform_remote_image_load_requested);
                }
            } else if (element_id == image_cache_clear_id) {
                if (model.runtime_image_cached_count > 0 and !model.runtime_image_load_pending and
                    !model.runtime_image_cache_clear_requested)
                {
                    emit(.{ .runtime_image_cache_clear_requested = .manual });
                }
            } else if (element_id == crash_export_id) {
                if (model.last_native_crash != null and !model.crash_report_export_pending) {
                    emit(.platform_crash_report_export_requested);
                }
            } else if (element_id == dialog_cancel_id) emit(.demo_dialog_closed) else if (element_id == dialog_confirm_id) emit(.demo_dialog_confirmed) else if (element_id == sort_select_id) {
                emit(.{ .demo_sort_expanded = !model.demo_sort_expanded });
            } else if (element_id == actions_menu_id) {
                emit(.{ .demo_menu_expanded = !model.demo_menu_expanded });
            } else if (navigationIndex(element_id)) |index| emit(.{ .demo_navigation_selected = index }) else if (tabIndex(element_id)) |index| emit(.{ .demo_tab_selected = index }) else if (treeIndex(element_id)) |index| emit(.{ .demo_tree_selected = index }) else if (accordionIndex(element_id)) |index| {
                emit(.{ .demo_accordion_expanded = accordion.nextExpandedMask(
                    model.demo_accordion_expanded_mask,
                    index,
                    !accordion.isExpanded(model.demo_accordion_expanded_mask, index),
                    .single,
                ) });
            } else if (radioIndex(element_id)) |index| emit(.{ .demo_density_selected = index }) else if (imageCacheBudgetIndex(element_id)) |index| {
                if (model.runtime_image_cache_budget_requested == null) {
                    emit(.{ .runtime_image_cache_budget_selected = index + 1 });
                }
            } else if (chipIndex(element_id)) |index| {
                if (!demo_filter_items[index].disabled) emit(.{ .demo_filter_toggled = index });
            } else if (selectOptionIndex(element_id)) |index| {
                state.focus_state.focus(sort_select_id);
                emit(.{ .demo_sort_selected = index });
                if (model.demo_sort_expanded) emit(.{ .demo_sort_expanded = false });
            } else if (menuItemIndex(element_id)) |index| {
                if (!demo_menu_items[index].disabled) {
                    state.focus_state.focus(actions_menu_id);
                    emit(.{ .demo_menu_item_activated = index });
                }
            } else if (virtualListIndex(element_id)) |index| {
                state.focus_state.focus(element_id);
                emit(.{ .demo_virtual_list_selected = index });
            } else if (dataTableHeaderIndex(element_id)) |index| {
                emit(.{ .demo_data_table_sorted = .{
                    .column_index = index,
                    .descending = model.demo_data_table_sort_column == index and
                        !model.demo_data_table_sort_descending,
                } });
            } else if (dataTableRowIndex(element_id)) |index| {
                emit(.{ .demo_data_table_row_selected = index });
            } else if (paginationTargetPage(model, element_id)) |page| {
                const filtered = demoTableFilteredOrder(
                    model.demo_data_table_sort_column,
                    model.demo_data_table_sort_descending,
                    model.searchText(),
                );
                const filtered_order = filtered.items();
                const current_page = pagination.boundedPage(
                    demoTablePageForRow(filtered_order, model.demo_data_table_selected_row),
                    pagination.pageCount(filtered_order.len, demo_table_page_size),
                );
                if (page != current_page) {
                    emit(.{ .demo_data_table_page_selected = @intCast(page) });
                    emit(.{ .demo_data_table_row_selected = @intCast(filtered_order[page * demo_table_page_size]) });
                }
            }
        },
        .increment, .decrement => {
            if (element_id == slider_id) {
                const delta: f32 = if (semantic_action == .increment) 0.05 else -0.05;
                emit(.{ .demo_volume_changed = @min(@max(model.demo_volume + delta, 0), 1) });
            } else if (element_id == retry_stepper_id) {
                emit(.{ .demo_retry_count_changed = number_stepper.steppedValue(
                    model.demo_retry_count,
                    0,
                    10,
                    1,
                    if (semantic_action == .increment) 1 else -1,
                ) });
            }
        },
        .set_text => if (textTargetForElement(element_id)) |target| {
            state.focus_state.focus(element_id);
            if (model.active_text_input != target) emit(.{ .text_input_focus_changed = target });
            emit(.text_select_all);
            emit(.{ .text_inserted = text });
        },
        .expand, .collapse => {
            const should_expand = semantic_action == .expand;
            if (element_id == sort_select_id) {
                if (model.demo_sort_expanded != should_expand) {
                    state.focus_state.focus(element_id);
                    emit(.{ .demo_sort_expanded = should_expand });
                }
            } else if (element_id == actions_menu_id) {
                if (model.demo_menu_expanded != should_expand) {
                    state.focus_state.focus(element_id);
                    emit(.{ .demo_menu_expanded = should_expand });
                }
            } else if (treeIndex(element_id)) |index| {
                const expanded = model.demo_tree_expanded_mask & (@as(u64, 1) << @intCast(index)) != 0;
                if (treeHasChildren(index) and expanded != should_expand) {
                    state.focus_state.focus(element_id);
                    emit(.{ .demo_tree_toggled = index });
                }
            } else if (accordionIndex(element_id)) |index| {
                const expanded = accordion.isExpanded(model.demo_accordion_expanded_mask, index);
                if (expanded != should_expand) {
                    state.focus_state.focus(element_id);
                    emit(.{ .demo_accordion_expanded = accordion.nextExpandedMask(
                        model.demo_accordion_expanded_mask,
                        index,
                        should_expand,
                        .single,
                    ) });
                }
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

fn activityPageItemIndex(element_id: u32) ?u8 {
    for (demo_activity_items, 0..) |_, index| {
        if (element_id == clay.ElementId.IDI("ActivityPageItem", @intCast(index)).id) return @intCast(index);
    }
    return null;
}

fn textTargetForElement(element_id: u32) ?text_edit.Target {
    if (element_id == clay.ElementId.ID("DemoTextField").id) return .application_name;
    if (element_id == clay.ElementId.ID("ProjectSearch").id) return .search;
    if (element_id == clay.ElementId.ID("RemoteImageUrl").id) return .remote_image_url;
    return null;
}

fn tabIndex(element_id: u32) ?u8 {
    for (demo_tab_items, 0..) |_, index| {
        if (element_id == tabs.itemId("DataTabs", index).id) return @intCast(index);
    }
    return null;
}

fn treeIndex(element_id: u32) ?u8 {
    for (demo_tree_items, 0..) |_, index| {
        if (element_id == tree_view.itemId("ProjectTree", index).id) return @intCast(index);
    }
    return null;
}

fn accordionIndex(element_id: u32) ?u8 {
    for (demo_accordion_items, 0..) |_, index| {
        if (element_id == accordion.headerId("SettingsAccordion", index).id) return @intCast(index);
    }
    return null;
}

fn treeHasChildren(index: u8) bool {
    for (demo_tree_items) |item| if (item.parent_index == index) return true;
    return false;
}

fn radioIndex(element_id: u32) ?u8 {
    for (demo_density_items, 0..) |_, index| {
        if (element_id == radio_group.itemId("DensityRadio", index).id) return @intCast(index);
    }
    return null;
}

fn imageCacheBudgetIndex(element_id: u32) ?u8 {
    for (image_cache_budget_items, 0..) |_, index| {
        if (element_id == radio_group.itemId("ImageCacheBudgetRadio", index).id) return @intCast(index);
    }
    return null;
}

fn chipIndex(element_id: u32) ?u8 {
    for (demo_filter_items, 0..) |_, index| {
        if (element_id == chip_group.itemId("StatusFilters", index).id) return @intCast(index);
    }
    return null;
}

fn selectOptionIndex(element_id: u32) ?u8 {
    for (demo_sort_items, 0..) |_, index| {
        if (element_id == select.optionId("SortSelect", index).id) return @intCast(index);
    }
    return null;
}

fn menuItemIndex(element_id: u32) ?u8 {
    for (demo_menu_items, 0..) |_, index| {
        if (element_id == menu.itemId("ActionsMenu", index).id) return @intCast(index);
    }
    return null;
}

fn virtualListIndex(element_id: u32) ?u16 {
    for (0..demo_virtual_list_item_count) |index| {
        if (element_id == virtual_list.itemId("RecordsVirtualList", index).id) return @intCast(index);
    }
    return null;
}

fn dataTableHeaderIndex(element_id: u32) ?u8 {
    for (0..4) |index| {
        if (element_id == data_table.headerId("RecordsDataTable", index).id) return @intCast(index);
    }
    return null;
}

fn dataTableRowIndex(element_id: u32) ?u8 {
    for (0..demo_table_rows.len) |index| {
        if (element_id == data_table.rowId("RecordsDataTable", index).id) return @intCast(index);
    }
    return null;
}

fn paginationPageIndex(element_id: u32) ?u8 {
    const count = pagination.pageCount(demo_table_rows.len, demo_table_page_size);
    for (0..count) |page| {
        if (element_id == pagination.pageId("RecordsPagination", page).id) return @intCast(page);
    }
    return null;
}

fn isPaginationElement(element_id: u32) bool {
    return paginationPageIndex(element_id) != null or
        element_id == pagination.previousId("RecordsPagination").id or
        element_id == pagination.nextId("RecordsPagination").id;
}

fn paginationTargetPage(model: *const Model, element_id: u32) ?usize {
    const filtered = demoTableFilteredOrder(
        model.demo_data_table_sort_column,
        model.demo_data_table_sort_descending,
        model.searchText(),
    );
    const order = filtered.items();
    if (order.len == 0) return null;
    const count = pagination.pageCount(order.len, demo_table_page_size);
    const current = pagination.boundedPage(
        demoTablePageForRow(order, model.demo_data_table_selected_row),
        count,
    );
    if (paginationPageIndex(element_id)) |page| {
        if (page < count) return page;
        return null;
    }
    if (element_id == pagination.previousId("RecordsPagination").id and current > 0) return current - 1;
    if (element_id == pagination.nextId("RecordsPagination").id and current + 1 < count) return current + 1;
    return null;
}

fn isInteractiveSemanticId(element_id: u32) bool {
    if (element_id == floating_window.closeId("DemoFloatingWindow").id) return true;
    if (navigationIndex(element_id) != null or tabIndex(element_id) != null or
        treeIndex(element_id) != null or
        accordionIndex(element_id) != null or
        radioIndex(element_id) != null or imageCacheBudgetIndex(element_id) != null or
        selectOptionIndex(element_id) != null) return true;
    if (chipIndex(element_id)) |index| return !demo_filter_items[index].disabled;
    if (menuItemIndex(element_id)) |index| return !demo_menu_items[index].disabled;
    if (virtualListIndex(element_id) != null) return true;
    if (dataTableHeaderIndex(element_id) != null or dataTableRowIndex(element_id) != null) return true;
    if (paginationPageIndex(element_id) != null or
        element_id == pagination.previousId("RecordsPagination").id or
        element_id == pagination.nextId("RecordsPagination").id) return true;
    if (element_id == select.triggerId("SortSelect").id or
        element_id == menu.triggerId("ActionsMenu").id) return true;
    inline for ([_][]const u8{
        "PrimaryAction",
        "IncrementProgress",
        "OpenDemoDialog",
        "OpenFloatingWindow",
        "DemoCheckbox",
        "DemoSwitch",
        "VolumeSlider",
        "RetryStepper",
        "ProjectSearch",
        "DemoTextField",
        "RemoteImageUrl",
        "LoadRemoteImage",
        "SubmitDemoForm",
        "RequestCameraPermission",
        "OpenFilePicker",
        "StreamSelectedFile",
        "LoadRuntimeImage",
        "ClearRuntimeImageCache",
        "ExportCrashReport",
        "DemoDialogCancel",
        "DemoDialogConfirm",
    }) |id| if (element_id == clay.ElementId.ID(id).id) return true;
    if (element_id == search_field.clearId("ProjectSearch").id) return true;
    return false;
}

fn isScrollableSemanticId(element_id: u32) bool {
    return element_id == clay.ElementId.ID("PrimaryCard").id or
        element_id == clay.ElementId.ID("ActivityPage").id or
        element_id == clay.ElementId.ID("SettingsPage").id or
        element_id == clay.ElementId.ID("ActivityScrollView").id or
        element_id == clay.ElementId.ID("RecordsVirtualList").id;
}

fn formatVirtualListItem(index: usize, buffer: []u8) []const u8 {
    return std.fmt.bufPrint(buffer, "数据记录 #{d}", .{index + 1}) catch "数据记录";
}

fn demoTextInvalid(model: *const Model) bool {
    return model.application_name_input.submission_count > 0 and std.mem.trim(u8, model.text(), " \t").len < 2;
}

fn drawActivityPage(compact: bool, input: interaction.Input) void {
    clay.UI()(card.declaration(.{
        .id = "ActivityPage",
        .scroll_vertical = true,
        .semantic_label = "活动页面",
        .semantic_registry = &state.semantic_registry,
    }))({
        _ = state.semantic_registry.pushScrollAncestor(clay.ElementId.ID("ActivityPage").id);
        label.draw("活动", .{
            .font_size = 22,
            .semantic_id = .ID("ActivityPageTitle"),
            .semantic_registry = &state.semantic_registry,
        });
        label.draw("跨平台应用框架的最新开发记录", .{
            .color = theme.controls.text_muted,
            .semantic_id = .ID("ActivityPageDescription"),
            .semantic_registry = &state.semantic_registry,
        });
        image_view.draw(.{
            .id = "ActivityThumbnail",
            .source = &activity_thumbnail_source,
            .width = if (compact) 220 else 280,
            .height = 112,
            .corner_radius = theme.controls.radius_medium,
            .semantic_label = "活动渐变缩略图",
            .semantic_registry = &state.semantic_registry,
        });
        clay.UI()(.{
            .id = .ID("ActivitySummary"),
            .layout = .{
                .sizing = .{ .w = .grow, .h = .fit },
                .padding = .all(if (compact) 14 else 18),
                .child_gap = theme.controls.gap_small,
                .direction = .top_to_bottom,
            },
            .background_color = .{ 24, 56, 70, 255 },
            .corner_radius = .all(theme.controls.radius_medium),
        })({
            label.draw("本周进展", .{
                .font_size = 18,
                .color = .{ 155, 211, 207, 255 },
                .semantic_id = .ID("ActivitySummaryTitle"),
                .semantic_registry = &state.semantic_registry,
            });
            label.draw("8 项能力已接入同一 AppModel / Action / reducer 数据流", .{
                .color = .{ 177, 220, 216, 255 },
                .semantic_id = .ID("ActivitySummaryBody"),
                .semantic_registry = &state.semantic_registry,
            });
        });
        for (demo_activity_items, 0..) |activity, activity_index| {
            clay.UI()(.{
                .id = .IDI("ActivityPageItemContainer", @intCast(activity_index)),
                .layout = .{
                    .sizing = .{ .w = .grow, .h = .fixed(if (compact) 48 else 54) },
                    .padding = .axes(14, 10),
                    .child_gap = theme.controls.gap_small,
                    .direction = .top_to_bottom,
                    .child_alignment = .{ .y = .center },
                },
                .background_color = theme.controls.surface,
                .corner_radius = .all(theme.controls.radius_small),
            })({
                label.draw(activity, .{
                    .color = theme.controls.text,
                    .semantic_id = .IDI("ActivityPageItem", @intCast(activity_index)),
                    .semantic_registry = &state.semantic_registry,
                });
                label.draw(if (activity_index < 2) "刚刚" else "本周", .{
                    .font_size = 12,
                    .color = theme.controls.text_muted,
                });
            });
        }
        state.semantic_registry.popScrollAncestor();
        scroll_bar.draw(&state.scroll_bar_state, input, .{
            .id = "ActivityPageScrollBar",
            .scroll_id = "ActivityPage",
        });
    });
}

fn drawSettingsPage(
    model: *const Model,
    input: interaction.Input,
    control_width: f32,
    control_direction: clay.LayoutDirection,
    narrow: bool,
    modal_open: bool,
) void {
    const checkbox_id = clay.ElementId.ID("DemoCheckbox").id;
    const switch_id = clay.ElementId.ID("DemoSwitch").id;
    clay.UI()(card.declaration(.{
        .id = "SettingsPage",
        .scroll_vertical = true,
        .semantic_label = "设置页面",
        .semantic_registry = &state.semantic_registry,
    }))({
        _ = state.semantic_registry.pushScrollAncestor(clay.ElementId.ID("SettingsPage").id);
        label.draw("设置", .{
            .font_size = 22,
            .semantic_id = .ID("SettingsPageTitle"),
            .semantic_registry = &state.semantic_registry,
        });
        label.draw("偏好由 AppModel 持有，切换页面不会丢失", .{
            .color = theme.controls.text_muted,
            .semantic_id = .ID("SettingsPageDescription"),
            .semantic_registry = &state.semantic_registry,
        });
        const accordion_result = accordion.draw(&state.interaction_state, input, .{
            .id = "SettingsAccordion",
            .items = &demo_accordion_items,
            .expanded_mask = model.demo_accordion_expanded_mask,
            .mode = .single,
            .width = control_width,
            .disabled = modal_open,
            .focused_id = state.focus_state.focused_id,
            .semantic_label = "应用设置分组",
            .semantic_registry = &state.semantic_registry,
            .draw_panel = drawDemoAccordionPanel,
            .panel_context = @ptrCast(&state.semantic_registry),
        });
        if (accordion_result.focus_index) |index| {
            state.focus_state.focus(accordion.headerId("SettingsAccordion", index).id);
        }
        if (accordion_result.expanded_mask) |mask| emit(.{ .demo_accordion_expanded = mask });
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
        label.draw("界面密度", .{
            .color = theme.controls.text_muted,
            .semantic_id = .ID("DensityRadioLabel"),
            .semantic_registry = &state.semantic_registry,
        });
        const radio_result = radio_group.draw(&state.interaction_state, input, .{
            .id = "DensityRadio",
            .items = &demo_density_items,
            .selected_index = model.demo_density_index,
            .item_width = if (narrow) control_width else 150,
            .direction = control_direction,
            .disabled = modal_open,
            .focused_id = state.focus_state.focused_id,
            .semantic_label = "界面密度",
            .semantic_registry = &state.semantic_registry,
        });
        if (radio_result.focus_index) |index| {
            state.focus_state.focus(radio_group.itemId("DensityRadio", index).id);
        }
        if (radio_result.selected_index) |index| {
            state.focus_state.focus(radio_group.itemId("DensityRadio", index).id);
            emit(.{ .demo_density_selected = @intCast(index) });
        }
        label.draw("动态图片缓存预算", .{
            .color = theme.controls.text_muted,
            .semantic_id = .ID("ImageCacheBudgetRadioLabel"),
            .semantic_registry = &state.semantic_registry,
        });
        const requested_budget = model.runtime_image_cache_budget_requested orelse
            model.runtime_image_cache_budget;
        const budget_result = radio_group.draw(&state.interaction_state, input, .{
            .id = "ImageCacheBudgetRadio",
            .items = &image_cache_budget_items,
            .selected_index = runtime_image.boundedCacheBudget(requested_budget) - 1,
            .item_width = if (narrow) control_width else 120,
            .direction = control_direction,
            .disabled = modal_open or model.runtime_image_cache_budget_requested != null,
            .focused_id = state.focus_state.focused_id,
            .semantic_label = "动态图片缓存预算",
            .semantic_registry = &state.semantic_registry,
        });
        if (budget_result.focus_index) |index| {
            state.focus_state.focus(radio_group.itemId("ImageCacheBudgetRadio", index).id);
        }
        if (budget_result.selected_index) |index| {
            state.focus_state.focus(radio_group.itemId("ImageCacheBudgetRadio", index).id);
            emit(.{ .runtime_image_cache_budget_selected = @intCast(index + 1) });
        }
        label.draw("缩减预算时按 LRU 立即释放超额 GPU 图片", .{
            .font_size = 13,
            .color = theme.controls.text_muted,
            .semantic_id = .ID("ImageCacheBudgetDescription"),
            .semantic_registry = &state.semantic_registry,
        });
        state.semantic_registry.popScrollAncestor();
        scroll_bar.draw(&state.scroll_bar_state, input, .{
            .id = "SettingsPageScrollBar",
            .scroll_id = "SettingsPage",
        });
    });
}

fn demoLayerLayoutWidth(viewport_width: i32) f32 {
    const horizontal_margin: i32 = if (viewport_width < 900) 96 else 360;
    return @min(@max(@as(f32, @floatFromInt(viewport_width - horizontal_margin)), 280), 680);
}

fn drawDemoLayer(context: ?*anyopaque, layer_id: u32) void {
    _ = context;
    switch (layer_id) {
        0 => {
            label.draw("Scene", .{ .font_size = 18, .color = theme.controls.text });
            label.draw("拖动标题可交换 Layer；拖动中间分隔条可调整宽度。", .{
                .font_size = 14,
                .color = theme.controls.text_muted,
                .wrap_mode = .words,
            });
        },
        else => {
            label.draw("Inspector", .{ .font_size = 18, .color = theme.controls.text });
            label.draw("布局顺序和分栏比例由 LayerLayout.State 保存。", .{
                .font_size = 14,
                .color = theme.controls.text_muted,
                .wrap_mode = .words,
            });
        },
    }
}

fn drawDemoFloatingWindowContent(context: ?*anyopaque) void {
    _ = context;
    label.draw("这是应用内部的可拖动子窗体。", .{
        .font_size = 16,
        .color = theme.controls.text,
    });
    label.draw("拖动标题栏移动，拖动右下角改变尺寸；窗口会保持在应用视口内。", .{
        .font_size = 14,
        .color = theme.controls.text_muted,
        .wrap_mode = .words,
    });
}

fn drawDemoAccordionPanel(context: ?*anyopaque, index: usize) void {
    const raw_registry = context orelse return;
    const registry: *semantics.Registry = @ptrCast(@alignCast(raw_registry));
    const body = switch (index) {
        1 => "推送通知与应用内提醒均由受控设置决定。",
        2 => "ZAPP 使用 Zig、Sokol 与 Clay 构建跨平台界面。",
        else => "账户与同步数据通过 AppModel 和 reducer 统一管理。",
    };
    const status = switch (index) {
        1 => "当前状态：接收应用通知",
        2 => "当前版本：开发环境",
        else => "同步状态：本地示例",
    };
    label.draw(body, .{
        .font_size = 14,
        .color = theme.controls.text_secondary,
        .semantic_id = .IDI("SettingsAccordionPanelBody", @intCast(index)),
        .semantic_registry = registry,
    });
    label.draw(status, .{
        .font_size = 13,
        .color = theme.controls.text_muted,
        .semantic_id = .IDI("SettingsAccordionPanelStatus", @intCast(index)),
        .semantic_registry = registry,
    });
}

fn formatDemoTableCell(row_index: usize, column_index: usize, buffer: []u8) []const u8 {
    const text = demoTableCell(row_index, column_index);
    const length = @min(buffer.len, text.len);
    @memcpy(buffer[0..length], text[0..length]);
    return buffer[0..length];
}

fn demoTableCell(row_index: usize, column_index: usize) []const u8 {
    if (row_index >= demo_table_rows.len) return "";
    const row = demo_table_rows[row_index];
    return switch (@min(column_index, 3)) {
        0 => row.code,
        1 => row.name,
        2 => row.status,
        else => row.updated,
    };
}

fn demoTableOrder(sort_column: usize, descending: bool) [demo_table_rows.len]usize {
    var order: [demo_table_rows.len]usize = undefined;
    for (&order, 0..) |*row_index, index| row_index.* = index;
    for (1..order.len) |index| {
        const current = order[index];
        var insertion = index;
        while (insertion > 0 and demoTableRowBefore(current, order[insertion - 1], sort_column, descending)) {
            order[insertion] = order[insertion - 1];
            insertion -= 1;
        }
        order[insertion] = current;
    }
    return order;
}

fn demoTableFilteredOrder(sort_column: usize, descending: bool, query: []const u8) DemoTableFilter {
    const sorted = demoTableOrder(sort_column, descending);
    var filtered: DemoTableFilter = .{};
    for (sorted) |row_index| {
        if (!demoTableRowMatches(row_index, query)) continue;
        filtered.order[filtered.count] = row_index;
        filtered.count += 1;
    }
    return filtered;
}

fn demoTableRowMatches(row_index: usize, raw_query: []const u8) bool {
    const query = std.mem.trim(u8, raw_query, " \t\r\n");
    if (query.len == 0) return true;
    for (0..4) |column_index| {
        if (containsAsciiInsensitive(demoTableCell(row_index, column_index), query)) return true;
    }
    return false;
}

fn containsAsciiInsensitive(haystack: []const u8, needle: []const u8) bool {
    if (needle.len == 0) return true;
    if (needle.len > haystack.len) return false;
    for (0..haystack.len - needle.len + 1) |start| {
        if (std.ascii.eqlIgnoreCase(haystack[start .. start + needle.len], needle)) return true;
    }
    return false;
}

fn demoTableRowBefore(left: usize, right: usize, sort_column: usize, descending: bool) bool {
    const primary = std.mem.order(u8, demoTableCell(left, sort_column), demoTableCell(right, sort_column));
    const order = if (primary == .eq)
        std.mem.order(u8, demoTableCell(left, 0), demoTableCell(right, 0))
    else
        primary;
    return if (descending) order == .gt else order == .lt;
}

fn demoTablePageForRow(order: []const usize, stable_row_index: usize) usize {
    for (order, 0..) |row_index, display_index| {
        if (row_index == stable_row_index) return display_index / demo_table_page_size;
    }
    return 0;
}

fn demoTableDisplayIndex(order: []const usize, stable_row_index: usize) ?usize {
    for (order, 0..) |row_index, display_index| {
        if (row_index == stable_row_index) return display_index;
    }
    return null;
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

const NestedScrollSnapshot = struct {
    inner_y: f32,
    outer_y: f32,
    pointer_delta: f32 = 0,
};

const WheelScrollPosition = struct {
    element_id: u32,
    y: f32,
};

const WheelScrollRoute = struct {
    positions: [semantics.max_nodes]WheelScrollPosition = undefined,
    position_count: usize = 0,
    target_id: u32,
    target_y: f32,
};

/// Resolve one explicit wheel owner from the previous frame's clipped semantic
/// regions. Clay still receives the wheel event so it can clear momentum, but
/// all positions are restored afterwards and only this owner gets the delta.
fn beginWheelScrollRoute(model: *const Model) ?WheelScrollRoute {
    if (@abs(model.scroll_delta_y) < 0.0001) return null;

    var route: WheelScrollRoute = .{ .target_id = 0, .target_y = 0 };
    var target_area = std.math.inf(f32);
    for (state.semantic_registry.items()) |node| {
        if (!node.scrollable) continue;
        var element_id = clay.ElementId.ID("");
        element_id.id = node.element_id;
        const scroll = clay.getScrollContainerData(element_id);
        if (!scroll.found or !scroll.config.vertical) continue;

        var already_saved = false;
        for (route.positions[0..route.position_count]) |position| {
            if (position.element_id == node.element_id) {
                already_saved = true;
                break;
            }
        }
        if (!already_saved and route.position_count < route.positions.len) {
            route.positions[route.position_count] = .{
                .element_id = node.element_id,
                .y = scroll.scroll_position.y,
            };
            route.position_count += 1;
        }

        if (node.bounds.width <= 0 or node.bounds.height <= 0 or
            model.pointer_x < node.bounds.x or
            model.pointer_x > node.bounds.x + node.bounds.width or
            model.pointer_y < node.bounds.y or
            model.pointer_y > node.bounds.y + node.bounds.height)
        {
            continue;
        }
        const area = node.bounds.width * node.bounds.height;
        if (area <= target_area) {
            target_area = area;
            route.target_id = node.element_id;
        }
    }

    // The embedded scrollbar is a sibling of the clipped VirtualList content,
    // so include the complete visible wrapper in the inner wheel target.
    if (model.demo_navigation_index == 0) {
        const wrapper = clay.getElementData(virtual_list.containerId("RecordsVirtualList"));
        const outer = clay.getElementData(clay.ElementId.ID("PrimaryCard"));
        if (wrapper.found and outer.found and
            pointInsideBounds(model.pointer_x, model.pointer_y, wrapper.bounding_box) and
            pointInsideBounds(model.pointer_x, model.pointer_y, outer.bounding_box))
        {
            route.target_id = clay.ElementId.ID("RecordsVirtualList").id;
        }
    }

    if (route.target_id == 0) return null;
    var target_element_id = clay.ElementId.ID("");
    target_element_id.id = route.target_id;
    const target = clay.getScrollContainerData(target_element_id);
    if (!target.found) return null;
    const max_scroll = @max(
        target.content_dimensions.h - target.scroll_container_dimensions.h,
        0,
    );
    route.target_y = @min(@max(
        target.scroll_position.y + model.scroll_delta_y * 360,
        -max_scroll,
    ), 0);
    return route;
}

fn restoreWheelScrollRoute(route: WheelScrollRoute) void {
    for (route.positions[0..route.position_count]) |position| {
        var element_id = clay.ElementId.ID("");
        element_id.id = position.element_id;
        const scroll = clay.getScrollContainerData(element_id);
        if (scroll.found) scroll.scroll_position.y = position.y;
    }
    var target_element_id = clay.ElementId.ID("");
    target_element_id.id = route.target_id;
    const target = clay.getScrollContainerData(target_element_id);
    if (target.found) target.scroll_position.y = route.target_y;
}

fn pointInsideBounds(x: f32, y: f32, bounds: clay.BoundingBox) bool {
    return x >= bounds.x and x <= bounds.x + bounds.width and
        y >= bounds.y and y <= bounds.y + bounds.height;
}

fn previousSemanticControlClaimsPointer(model: *const Model) bool {
    if (model.pointer_down and state.interaction_state.active_id != null) return true;
    if (!model.pointer_pressed) return false;
    for (state.semantic_registry.items()) |node| {
        if (node.disabled or !semanticRoleCapturesPointer(node.role) or
            node.bounds.width <= 0 or node.bounds.height <= 0)
        {
            continue;
        }
        if (model.pointer_x >= node.bounds.x and
            model.pointer_x <= node.bounds.x + node.bounds.width and
            model.pointer_y >= node.bounds.y and
            model.pointer_y <= node.bounds.y + node.bounds.height)
        {
            return true;
        }
    }
    return false;
}

fn semanticRoleCapturesPointer(role: semantics.Role) bool {
    return switch (role) {
        .button,
        .checkbox,
        .switch_control,
        .slider,
        .text_field,
        .navigation_item,
        .tree_item,
        .radio_button,
        .combo_box,
        .option,
        .tab,
        .menu_item,
        .list_item,
        .row,
        .column_header,
        .chip,
        .spin_button,
        => true,
        else => false,
    };
}

fn virtualListScrollBarOuterTarget(model: *const Model) ?f32 {
    const track_id = clay.ElementId.ID("VirtualListScrollBar");
    const track = clay.getElementData(track_id);
    const active = state.virtual_list_state.scroll_bar_state.active_id == track_id.id;
    const pressing_track = model.pointer_pressed and track.found and
        pointInsideBounds(model.pointer_x, model.pointer_y, track.bounding_box);
    if (!active and !pressing_track) return null;
    const outer = clay.getScrollContainerData(clay.ElementId.ID("PrimaryCard"));
    return if (outer.found) outer.scroll_position.y else null;
}

fn restorePrimaryScrollPosition(target_y: f32) void {
    const outer = clay.getScrollContainerData(clay.ElementId.ID("PrimaryCard"));
    if (outer.found) outer.scroll_position.y = target_y;
}

/// Pointer ownership is fixed on press. Leaving the visible list bounds does
/// not hand the gesture to the parent card; ownership ends only on release.
fn beginNestedBoundaryScroll(model: *const Model) ?NestedScrollSnapshot {
    if (model.pointer_pressed) {
        const list = clay.getElementData(clay.ElementId.ID("RecordsVirtualList"));
        const outer = clay.getElementData(clay.ElementId.ID("PrimaryCard"));
        state.nested_scroll_active = model.demo_navigation_index == 0 and
            list.found and outer.found and
            pointInsideBounds(model.pointer_x, model.pointer_y, list.bounding_box) and
            pointInsideBounds(model.pointer_x, model.pointer_y, outer.bounding_box) and
            !pointerInVirtualListScrollBar(model);
        state.nested_scroll_pointer_y = model.pointer_y;
    }
    if (!state.nested_scroll_active or !model.pointer_down or
        model.demo_navigation_index != 0)
    {
        return null;
    }
    const inner = clay.getScrollContainerData(clay.ElementId.ID("RecordsVirtualList"));
    const outer = clay.getScrollContainerData(clay.ElementId.ID("PrimaryCard"));
    if (!inner.found or !inner.config.vertical or !outer.found or !outer.config.vertical) return null;
    const pointer_delta = model.pointer_y - state.nested_scroll_pointer_y;
    state.nested_scroll_pointer_y = model.pointer_y;
    return .{
        .inner_y = inner.scroll_position.y,
        .outer_y = outer.scroll_position.y,
        .pointer_delta = pointer_delta,
    };
}

fn applyNestedCapturedScroll(before: NestedScrollSnapshot) void {
    const inner = clay.getScrollContainerData(clay.ElementId.ID("RecordsVirtualList"));
    const outer = clay.getScrollContainerData(clay.ElementId.ID("PrimaryCard"));
    if (!inner.found or !outer.found) return;
    const inner_max = @max(inner.content_dimensions.h - demo_virtual_list_height, 0);
    inner.scroll_position.y = @min(@max(
        before.inner_y + before.pointer_delta,
        -inner_max,
    ), 0);
    outer.scroll_position.y = before.outer_y;
}

fn pointerInVirtualListScrollBar(model: *const Model) bool {
    const track = clay.getElementData(clay.ElementId.ID("VirtualListScrollBar"));
    return track.found and pointInsideBounds(model.pointer_x, model.pointer_y, track.bounding_box);
}

fn ensureElementVisibleInScrollContainer(element_value: u32, container_value: u32) void {
    var element_id = clay.ElementId.ID("");
    element_id.id = element_value;
    var container_id = clay.ElementId.ID("");
    container_id.id = container_value;
    const element = clay.getElementData(element_id);
    const container = clay.getElementData(container_id);
    const scroll = clay.getScrollContainerData(container_id);
    if (!element.found or !container.found or !scroll.found or !scroll.config.vertical) return;

    const horizontal_overlap = element.bounding_box.x + element.bounding_box.width > container.bounding_box.x and
        element.bounding_box.x < container.bounding_box.x + container.bounding_box.width;
    if (!horizontal_overlap) return;
    const current_y = scroll.scroll_position.y;
    const visible_top = container.bounding_box.y;
    const visible_bottom = visible_top + container.bounding_box.height;
    const element_top = element.bounding_box.y;
    const element_bottom = element_top + element.bounding_box.height;
    var target_y = current_y;
    if (element_top < visible_top) {
        target_y += visible_top - element_top;
    } else if (element_bottom > visible_bottom) {
        target_y -= element_bottom - visible_bottom;
    }
    const max_scroll = @max(scroll.content_dimensions.h - scroll.scroll_container_dimensions.h, 0);
    scroll.scroll_position.y = @min(@max(target_y, -max_scroll), 0);
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

fn signalName(signal_number: i32) []const u8 {
    return switch (signal_number) {
        4 => "SIGILL",
        5 => "SIGTRAP",
        6 => "SIGABRT",
        7 => "SIGBUS",
        8 => "SIGFPE",
        11 => "SIGSEGV",
        31 => "SIGSYS",
        else => "SIGNAL",
    };
}

fn crashArchitectureName(architecture: @import("../platform/platform.zig").CrashArchitecture) []const u8 {
    return switch (architecture) {
        .arm64 => "arm64-v8a",
        .x86_64 => "x86_64",
        .unknown => "unknown ABI",
    };
}

fn formatCrashBuildId(
    buffer: []u8,
    report: *const @import("../platform/platform.zig").NativeCrashReport,
) []const u8 {
    const bytes = report.buildId();
    if (bytes.len == 0) return "";
    const prefix = "Build ID：";
    if (prefix.len + bytes.len * 2 > buffer.len) return "Build ID 不可用";
    @memcpy(buffer[0..prefix.len], prefix);
    const digits = "0123456789abcdef";
    for (bytes, 0..) |byte, index| {
        buffer[prefix.len + index * 2] = digits[byte >> 4];
        buffer[prefix.len + index * 2 + 1] = digits[byte & 0x0f];
    }
    return buffer[0 .. prefix.len + bytes.len * 2];
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

fn runtimeImageTooLarge(model: *const Model) bool {
    return model.file_size_known and model.file_size > runtime_image.max_encoded_bytes;
}

fn formatRuntimeImageStatus(buffer: []u8, model: *const Model) []const u8 {
    if (runtimeImageTooLarge(model) and !model.runtime_image_load_pending) return std.fmt.bufPrint(
        buffer,
        "图片未加载：编码文件超过 {d} MiB 上限",
        .{runtime_image.max_encoded_bytes / (1024 * 1024)},
    ) catch "图片状态不可用";
    if (model.runtime_image_error) |error_kind| return switch (error_kind) {
        .invalid_data => "图片加载失败：仅支持有效的 PNG 或 JPEG",
        .encoded_limit_exceeded => "图片加载失败：编码文件超过 16 MiB 上限",
        .decoded_limit_exceeded => "图片加载失败：尺寸超过 4096 或 RGBA 数据超过 64 MiB",
        .out_of_memory => "图片加载失败：内存不足",
        .gpu_upload_failed => "图片加载失败：GPU 纹理创建失败",
        .interrupted => "图片加载已取消或数据流不连续",
        .invalid_uri => "图片加载失败：URI 无效",
        .not_found => "图片加载失败：文件不存在",
        .permission_denied => "图片加载失败：没有读取权限",
        .io => "图片加载失败：I/O 错误",
        .unsupported => "图片加载失败：平台不支持",
    };
    if (model.runtime_image_load_pending) {
        const phase = if (model.runtime_image_cancel_pending) "正在取消" else "正在加载";
        return if (model.file_size_known)
            std.fmt.bufPrint(
                buffer,
                "图片{s}：{d} / {d} 字节",
                .{ phase, model.runtime_image_bytes_received, model.file_size },
            ) catch "图片状态不可用"
        else
            std.fmt.bufPrint(
                buffer,
                "图片{s}：{d} 字节",
                .{ phase, model.runtime_image_bytes_received },
            ) catch "图片状态不可用";
    }
    if (model.runtime_image_loaded) return std.fmt.bufPrint(
        buffer,
        "运行时图片：{d} × {d}，编码数据 {d} 字节｜缓存{s}（{d}/{d}）",
        .{
            model.runtime_image_width,
            model.runtime_image_height,
            model.runtime_image_bytes_received,
            if (model.runtime_image_cache_hit) "命中" else "新增",
            model.runtime_image_cached_count,
            model.runtime_image_cache_budget,
        },
    ) catch "图片状态不可用";
    if (model.last_runtime_image_cache_clear_reason) |reason| return std.fmt.bufPrint(
        buffer,
        "图片缓存已释放：{s}，共 {d} 个动态槽",
        .{
            if (reason == .manual) "用户操作" else "系统内存压力",
            model.last_runtime_image_cache_released_count,
        },
    ) catch "图片状态不可用";
    if (model.last_runtime_image_budget_released_count > 0) return std.fmt.bufPrint(
        buffer,
        "图片缓存预算已调整为 {d} 槽，按 LRU 淘汰 {d} 个动态槽",
        .{ model.runtime_image_cache_budget, model.last_runtime_image_budget_released_count },
    ) catch "图片状态不可用";
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
    var scissor_end_count: usize = 0;
    var image_count: usize = 0;
    for (result.commands) |command| {
        if (command.command_type == .rectangle) rectangle_count += 1;
        if (command.command_type == .text) text_count += 1;
        if (command.command_type == .scissor_start) scissor_count += 1;
        if (command.command_type == .image) image_count += 1;
        if (command.command_type == .scissor_end) scissor_end_count += 1;
    }

    try std.testing.expect(rectangle_count >= 14);
    try std.testing.expect(text_count >= 14);
    try std.testing.expect(scissor_count >= 1);
    try std.testing.expectEqual(scissor_count, scissor_end_count);
    try std.testing.expectEqual(@as(usize, 1), image_count);
    try std.testing.expectEqual(@as(usize, 0), result.actions.len);
    try std.testing.expect(result.clear_color.a == 1);
    try std.testing.expect(result.semantic_nodes.len >= 10);
    var has_slider_semantics = false;
    var has_stepper_semantics = false;
    var has_image_semantics = false;
    var has_text_field_semantics = false;
    var has_required_valid_text_field = false;
    var has_form_submit_button = false;
    var has_text_semantics = false;
    var has_progress_semantics = false;
    var has_list_semantics = false;
    var has_forward_scroll_semantics = false;
    var has_tree_semantics = false;
    var has_expanded_tree_item = false;
    var has_accordion_semantics = false;
    var accordion_header_count: usize = 0;
    var expanded_accordion_header_count: usize = 0;
    var has_first_accordion_panel = false;
    var has_radio_group_semantics = false;
    var has_checked_radio_semantics = false;
    var chip_semantic_count: usize = 0;
    var checked_chip_count: usize = 0;
    var has_disabled_chip = false;
    var has_combo_box_semantics = false;
    var has_tab_list_semantics = false;
    var selected_tab_count: usize = 0;
    var has_collapsed_menu_button = false;
    var has_virtual_list_semantics = false;
    var visible_virtual_item_count: usize = 0;
    var selected_virtual_item_count: usize = 0;
    var has_data_table_semantics = false;
    var table_header_count: usize = 0;
    var table_row_count: usize = 0;
    var selected_table_row_count: usize = 0;
    var has_pagination_semantics = false;
    var selected_page_count: usize = 0;
    var previous_page_disabled = false;
    var has_performance_label_semantics = false;
    var has_crash_diagnostics_semantics = false;
    for (result.semantic_nodes) |node| {
        try std.testing.expect(std.mem.indexOfScalar(u8, node.label, 0) == null);
        try std.testing.expect(std.mem.indexOfScalar(u8, node.value_text, 0) == null);
        try std.testing.expect(std.unicode.utf8ValidateSlice(node.label));
        try std.testing.expect(std.unicode.utf8ValidateSlice(node.value_text));
        if (node.role == .slider and node.value != null) has_slider_semantics = true;
        if (node.role == .spin_button and node.value == 3 and node.value_min == 0 and
            node.value_max == 10 and node.value_step == 1)
        {
            has_stepper_semantics = true;
        }
        if (node.element_id == clay.ElementId.ID("DemoHeroImage").id and
            node.role == .image and std.mem.eql(u8, node.label, "蓝色渐变应用封面"))
        {
            has_image_semantics = true;
        }
        if (node.role == .text_field and node.value_text.len == model.text().len) has_text_field_semantics = true;
        if (node.element_id == clay.ElementId.ID("DemoTextField").id and node.required and
            !node.invalid and node.error_text.len == 0)
        {
            has_required_valid_text_field = true;
        }
        if (node.element_id == clay.ElementId.ID("SubmitDemoForm").id and node.role == .button) {
            has_form_submit_button = true;
        }
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
        if (node.element_id == clay.ElementId.ID("SettingsAccordion").id) has_accordion_semantics = true;
        if (accordionIndex(node.element_id) != null) {
            accordion_header_count += 1;
            if (node.expanded == true) expanded_accordion_header_count += 1;
        }
        if (node.element_id == accordion.panelId("SettingsAccordion", 0).id) {
            has_first_accordion_panel = true;
        }
        if (node.role == .radio_group) has_radio_group_semantics = true;
        if (node.role == .radio_button and node.checked == true) has_checked_radio_semantics = true;
        if (node.role == .chip) {
            chip_semantic_count += 1;
            if (node.checked == true) checked_chip_count += 1;
            if (node.disabled) has_disabled_chip = true;
        }
        if (node.role == .combo_box and node.expanded == false and node.value_text.len > 0) {
            has_combo_box_semantics = true;
        }
        if (node.role == .tab_list) has_tab_list_semantics = true;
        if (node.role == .tab and node.selected) selected_tab_count += 1;
        if (node.element_id == menu.triggerId("ActionsMenu").id and node.expanded == false) {
            has_collapsed_menu_button = true;
        }
        if (node.element_id == clay.ElementId.ID("RecordsVirtualList").id and node.scrollable) {
            has_virtual_list_semantics = true;
        }
        if (node.role == .list_item) {
            visible_virtual_item_count += 1;
            if (node.selected) selected_virtual_item_count += 1;
        }
        if (node.role == .table and node.row_count == demo_table_page_size + 1 and node.column_count == 4) {
            has_data_table_semantics = true;
        }
        if (node.role == .column_header) {
            table_header_count += 1;
            try std.testing.expectEqual(@as(u16, 0), node.row_index);
        }
        if (node.role == .row) {
            table_row_count += 1;
            if (node.selected) selected_table_row_count += 1;
            try std.testing.expectEqual(@as(u16, 4), node.column_span);
        }
        if (node.element_id == clay.ElementId.ID("RecordsPagination").id and
            std.mem.indexOf(u8, node.value_text, "第 1 页，共 3 页") != null)
        {
            has_pagination_semantics = true;
        }
        if (paginationPageIndex(node.element_id) != null and node.selected) selected_page_count += 1;
        if (node.element_id == pagination.previousId("RecordsPagination").id and node.disabled) {
            previous_page_disabled = true;
        }
        if (node.element_id == clay.ElementId.ID("PerformanceMetricsLabel").id) has_performance_label_semantics = true;
        if (node.element_id == clay.ElementId.ID("CrashDiagnosticsStatus").id) {
            has_crash_diagnostics_semantics = true;
        }
    }
    try std.testing.expect(has_slider_semantics);
    try std.testing.expect(has_stepper_semantics);
    try std.testing.expect(has_image_semantics);
    try std.testing.expect(has_text_field_semantics);
    try std.testing.expect(has_required_valid_text_field);
    try std.testing.expect(has_form_submit_button);
    try std.testing.expect(has_text_semantics);
    try std.testing.expect(has_progress_semantics);
    try std.testing.expect(has_list_semantics);
    try std.testing.expect(has_forward_scroll_semantics);
    try std.testing.expect(has_tree_semantics);
    try std.testing.expect(has_expanded_tree_item);
    try std.testing.expect(has_accordion_semantics);
    try std.testing.expectEqual(demo_accordion_items.len, accordion_header_count);
    try std.testing.expectEqual(@as(usize, 1), expanded_accordion_header_count);
    try std.testing.expect(has_first_accordion_panel);
    try std.testing.expect(has_radio_group_semantics);
    try std.testing.expect(has_checked_radio_semantics);
    try std.testing.expectEqual(demo_filter_items.len, chip_semantic_count);
    try std.testing.expectEqual(@as(usize, 2), checked_chip_count);
    try std.testing.expect(has_disabled_chip);
    try std.testing.expect(has_combo_box_semantics);
    try std.testing.expect(has_tab_list_semantics);
    try std.testing.expectEqual(@as(usize, 1), selected_tab_count);
    try std.testing.expect(has_collapsed_menu_button);
    try std.testing.expect(has_virtual_list_semantics);
    try std.testing.expect(visible_virtual_item_count > 0);
    try std.testing.expect(visible_virtual_item_count < virtual_list.max_visible_rows);
    try std.testing.expectEqual(@as(usize, 1), selected_virtual_item_count);
    try std.testing.expect(has_data_table_semantics);
    try std.testing.expectEqual(@as(usize, 4), table_header_count);
    try std.testing.expectEqual(@as(usize, demo_table_page_size), table_row_count);
    try std.testing.expectEqual(@as(usize, 1), selected_table_row_count);
    try std.testing.expect(has_pagination_semantics);
    try std.testing.expectEqual(@as(usize, 1), selected_page_count);
    try std.testing.expect(previous_page_disabled);
    try std.testing.expect(has_performance_label_semantics);
    try std.testing.expect(has_crash_diagnostics_semantics);

    const primary_scroll = clay.getScrollContainerData(clay.ElementId.ID("PrimaryCard"));
    try std.testing.expect(primary_scroll.found);
    const primary_data = clay.getElementData(clay.ElementId.ID("PrimaryCard"));
    try std.testing.expect(primary_data.found);
    const primary_max_scroll = @max(
        primary_scroll.content_dimensions.h - primary_scroll.scroll_container_dimensions.h,
        0,
    );
    try std.testing.expect(primary_max_scroll > 0);
    primary_scroll.scroll_position.y = 0;
    _ = build(&model);
    const first_primary_content = clay.getElementData(clay.ElementId.ID("PrimaryCardTitle"));
    try std.testing.expect(first_primary_content.found);
    try std.testing.expect(first_primary_content.bounding_box.y >= primary_data.bounding_box.y);
    primary_scroll.scroll_position.y = -primary_max_scroll;
    _ = build(&model);
    const last_primary_content = clay.getElementData(clay.ElementId.ID("DialogConfirmationCount"));
    try std.testing.expect(last_primary_content.found);
    try std.testing.expect(last_primary_content.bounding_box.y + last_primary_content.bounding_box.height <=
        primary_data.bounding_box.y + primary_data.bounding_box.height);
    try std.testing.expect(last_primary_content.bounding_box.y + last_primary_content.bounding_box.height >
        primary_data.bounding_box.y);
    primary_scroll.scroll_position.y = 0;
    model.pointer_x = primary_data.bounding_box.x + primary_data.bounding_box.width * 0.75;
    for (0..6) |_| {
        model.pointer_y = primary_data.bounding_box.y + primary_data.bounding_box.height - 40;
        model.pointer_down = false;
        _ = build(&model);
        model.pointer_down = true;
        _ = build(&model);
        model.pointer_y = primary_data.bounding_box.y + 40;
        _ = build(&model);
        model.pointer_down = false;
        _ = build(&model);
    }
    try std.testing.expectApproxEqAbs(-primary_max_scroll, primary_scroll.scroll_position.y, 1);
    for (0..6) |_| {
        model.pointer_y = primary_data.bounding_box.y + 40;
        model.pointer_down = false;
        _ = build(&model);
        model.pointer_down = true;
        _ = build(&model);
        model.pointer_y = primary_data.bounding_box.y + primary_data.bounding_box.height - 40;
        _ = build(&model);
        model.pointer_down = false;
        _ = build(&model);
    }
    try std.testing.expectApproxEqAbs(@as(f32, 0), primary_scroll.scroll_position.y, 1);

    // A pointer-clicked control may keep focus, but focus reveal is a one-shot
    // event. Subsequent user scrolling must not pull the card back to it.
    state.focus_state.focus(clay.ElementId.ID("PrimaryAction").id);
    _ = build(&model);
    _ = build(&model);
    primary_scroll.scroll_position.y = -500;
    _ = build(&model);
    try std.testing.expectApproxEqAbs(@as(f32, -500), primary_scroll.scroll_position.y, 0.01);
    state.focus_state.focused_id = null;
    _ = build(&model);

    ensureElementVisibleInScrollContainer(
        clay.ElementId.ID("RecordsVirtualList").id,
        clay.ElementId.ID("PrimaryCard").id,
    );
    _ = build(&model);
    const virtual_list_data = clay.getElementData(clay.ElementId.ID("RecordsVirtualList"));
    const virtual_list_scroll = clay.getScrollContainerData(clay.ElementId.ID("RecordsVirtualList"));
    try std.testing.expect(virtual_list_data.found and virtual_list_scroll.found);
    const outer_before_nested_drag = primary_scroll.scroll_position.y;
    const inner_before_nested_drag = virtual_list_scroll.scroll_position.y;
    model.pointer_x = virtual_list_data.bounding_box.x + virtual_list_data.bounding_box.width * 0.5;
    model.pointer_y = virtual_list_data.bounding_box.y + virtual_list_data.bounding_box.height * 0.7;
    model.pointer_down = false;
    _ = build(&model);
    model.pointer_down = true;
    model.pointer_pressed = true;
    _ = build(&model);
    model.pointer_pressed = false;
    model.pointer_y -= 80;
    _ = build(&model);
    try std.testing.expectApproxEqAbs(
        outer_before_nested_drag,
        primary_scroll.scroll_position.y,
        0.01,
    );
    try std.testing.expect(virtual_list_scroll.scroll_position.y < inner_before_nested_drag - 40);
    model.pointer_down = false;
    model.pointer_released = true;
    const nested_scrolled_frame = build(&model);
    model.pointer_released = false;
    var nested_item_count: usize = 0;
    for (nested_scrolled_frame.semantic_nodes) |node| {
        if (node.role != .list_item) continue;
        nested_item_count += 1;
        try std.testing.expect(node.bounds.y >= virtual_list_data.bounding_box.y);
        try std.testing.expect(node.bounds.y + node.bounds.height <=
            virtual_list_data.bounding_box.y + virtual_list_data.bounding_box.height);
    }
    try std.testing.expect(nested_item_count > 0);
    model.pointer_x = 0;
    model.pointer_y = 0;
    for (0..120) |_| _ = build(&model);

    // Mouse-wheel input uses Clay's scroll-delta path rather than pointer
    // dragging. It must keep the card stationary and preserve the complete
    // nested scissor stack while the virtual window changes.
    virtual_list_scroll.scroll_position.y = 0;
    ensureElementVisibleInScrollContainer(
        clay.ElementId.ID("RecordsVirtualList").id,
        clay.ElementId.ID("PrimaryCard").id,
    );
    _ = build(&model);
    const wheel_list_data = clay.getElementData(clay.ElementId.ID("RecordsVirtualList"));
    try std.testing.expect(wheel_list_data.found);
    const outer_before_wheel = primary_scroll.scroll_position.y;
    const primary_height_before_wheel = primary_scroll.content_dimensions.h;
    model.pointer_x = wheel_list_data.bounding_box.x + wheel_list_data.bounding_box.width * 0.5;
    model.pointer_y = wheel_list_data.bounding_box.y + wheel_list_data.bounding_box.height * 0.5;
    model.scroll_delta_y = -1;
    const wheel_frame = build(&model);
    model.scroll_delta_y = 0;
    try std.testing.expect(virtual_list_scroll.scroll_position.y < -100);
    try std.testing.expectApproxEqAbs(outer_before_wheel, primary_scroll.scroll_position.y, 0.01);
    const inner_after_list_wheel = virtual_list_scroll.scroll_position.y;
    const outer_before_followup_wheel = primary_scroll.scroll_position.y;
    // Real input has idle render frames between distinct wheel events. The
    // inner target must not survive that gap and capture the outer event.
    _ = build(&model);
    model.pointer_x = primary_data.bounding_box.x + 12;
    model.pointer_y = primary_data.bounding_box.y + 12;
    model.scroll_delta_y = -1;
    _ = build(&model);
    model.scroll_delta_y = 0;
    try std.testing.expect(primary_scroll.scroll_position.y < outer_before_followup_wheel - 100);
    try std.testing.expectApproxEqAbs(
        inner_after_list_wheel,
        virtual_list_scroll.scroll_position.y,
        0.01,
    );
    primary_scroll.scroll_position.y = outer_before_followup_wheel;
    try std.testing.expectApproxEqAbs(
        primary_height_before_wheel,
        primary_scroll.content_dimensions.h,
        0.01,
    );
    var wheel_scissor_depth: isize = 0;
    var wheel_min_scissor_depth: isize = 0;
    var wheel_bar_inside_clip = false;
    for (wheel_frame.commands) |command| {
        if (command.command_type == .scissor_start) wheel_scissor_depth += 1;
        if (command.id == clay.ElementId.ID("VirtualListScrollBar").id and
            command.command_type == .rectangle)
        {
            wheel_bar_inside_clip = wheel_scissor_depth > 0;
        }
        if (command.command_type == .scissor_end) {
            wheel_scissor_depth -= 1;
            wheel_min_scissor_depth = @min(wheel_min_scissor_depth, wheel_scissor_depth);
        }
    }
    try std.testing.expectEqual(@as(isize, 0), wheel_scissor_depth);
    try std.testing.expectEqual(@as(isize, 0), wheel_min_scissor_depth);
    try std.testing.expect(wheel_bar_inside_clip);

    // The embedded track is outside the clipped content element but inside
    // the VirtualList wrapper. Wheel input there must still target the list,
    // never the PrimaryCard.
    virtual_list_scroll.scroll_position.y = 0;
    _ = build(&model);
    const wheel_wrapper_data = clay.getElementData(virtual_list.containerId("RecordsVirtualList"));
    const wheel_content_data = clay.getElementData(clay.ElementId.ID("RecordsVirtualList"));
    try std.testing.expect(wheel_wrapper_data.found and wheel_content_data.found);
    const outer_before_track_wheel = primary_scroll.scroll_position.y;
    model.pointer_x = (wheel_content_data.bounding_box.x + wheel_content_data.bounding_box.width +
        wheel_wrapper_data.bounding_box.x + wheel_wrapper_data.bounding_box.width) * 0.5;
    model.pointer_y = wheel_wrapper_data.bounding_box.y + wheel_wrapper_data.bounding_box.height * 0.5;
    model.scroll_delta_y = -1;
    _ = build(&model);
    model.scroll_delta_y = 0;
    try std.testing.expect(virtual_list_scroll.scroll_position.y < -100);
    try std.testing.expectApproxEqAbs(
        outer_before_track_wheel,
        primary_scroll.scroll_position.y,
        0.01,
    );

    const wheel_inner_max = @max(
        virtual_list_scroll.content_dimensions.h - demo_virtual_list_height,
        0,
    );
    virtual_list_scroll.scroll_position.y = -wheel_inner_max + 30;
    _ = build(&model);
    const outer_before_wheel_boundary = primary_scroll.scroll_position.y;
    model.scroll_delta_y = -1;
    _ = build(&model);
    model.scroll_delta_y = 0;
    try std.testing.expectApproxEqAbs(-wheel_inner_max, virtual_list_scroll.scroll_position.y, 0.01);
    // Wheel input stays owned by the virtual list even when it reaches an
    // endpoint. Discarding the rejected remainder prevents the parent card
    // from moving under a stationary pointer.
    try std.testing.expectApproxEqAbs(
        outer_before_wheel_boundary,
        primary_scroll.scroll_position.y,
        0.01,
    );

    // Pressing the embedded thumb must claim the pointer before Clay chooses
    // a scroll container. During the drag only the virtual list may move.
    virtual_list_scroll.scroll_position.y = 0;
    _ = build(&model);
    const drag_track = clay.getElementData(clay.ElementId.ID("VirtualListScrollBar"));
    try std.testing.expect(drag_track.found);
    const outer_before_thumb_drag = primary_scroll.scroll_position.y;
    model.pointer_x = drag_track.bounding_box.x + drag_track.bounding_box.width * 0.5;
    model.pointer_y = drag_track.bounding_box.y + 8;
    model.pointer_down = true;
    model.pointer_pressed = true;
    _ = build(&model);
    model.pointer_pressed = false;
    try std.testing.expectEqual(
        clay.ElementId.ID("VirtualListScrollBar").id,
        state.virtual_list_state.scroll_bar_state.active_id.?,
    );
    model.pointer_y = drag_track.bounding_box.y + drag_track.bounding_box.height - 8;
    _ = build(&model);
    try std.testing.expect(virtual_list_scroll.scroll_position.y < -wheel_inner_max * 0.8);
    try std.testing.expectApproxEqAbs(
        outer_before_thumb_drag,
        primary_scroll.scroll_position.y,
        0.01,
    );
    model.pointer_down = false;
    model.pointer_released = true;
    _ = build(&model);
    model.pointer_released = false;
    model.pointer_x = 0;
    model.pointer_y = 0;

    // Slow movement must remain owned by the virtual list until it truly
    // reaches an endpoint. This is the case the former delta-only heuristic
    // got wrong on touch devices.
    virtual_list_scroll.scroll_position.y = 0;
    ensureElementVisibleInScrollContainer(
        clay.ElementId.ID("RecordsVirtualList").id,
        clay.ElementId.ID("PrimaryCard").id,
    );
    _ = build(&model);
    const slow_list_data = clay.getElementData(clay.ElementId.ID("RecordsVirtualList"));
    try std.testing.expect(slow_list_data.found);
    const outer_before_slow_drag = primary_scroll.scroll_position.y;
    const primary_content_height = primary_scroll.content_dimensions.h;
    model.pointer_x = slow_list_data.bounding_box.x + slow_list_data.bounding_box.width * 0.5;
    model.pointer_y = slow_list_data.bounding_box.y + slow_list_data.bounding_box.height * 0.7;
    model.pointer_down = true;
    model.pointer_pressed = true;
    _ = build(&model);
    model.pointer_pressed = false;
    for (0..8) |_| {
        model.pointer_y -= 8;
        _ = build(&model);
    }
    try std.testing.expect(virtual_list_scroll.scroll_position.y < -50);
    try std.testing.expectApproxEqAbs(
        outer_before_slow_drag,
        primary_scroll.scroll_position.y,
        0.01,
    );
    try std.testing.expectApproxEqAbs(
        primary_content_height,
        primary_scroll.content_dimensions.h,
        0.01,
    );
    model.pointer_down = false;
    model.pointer_released = true;
    _ = build(&model);
    model.pointer_released = false;
    model.pointer_x = 0;
    model.pointer_y = 0;
    for (0..120) |_| _ = build(&model);

    // Ownership remains with the list even after the pointer leaves its
    // bounds and the list reaches its endpoint.
    const virtual_max_scroll = @max(
        virtual_list_scroll.content_dimensions.h - demo_virtual_list_height,
        0,
    );
    virtual_list_scroll.scroll_position.y = -virtual_max_scroll + 30;
    _ = build(&model);
    const outer_before_boundary_drag = primary_scroll.scroll_position.y;
    const boundary_list_data = clay.getElementData(clay.ElementId.ID("RecordsVirtualList"));
    try std.testing.expect(boundary_list_data.found);
    model.pointer_x = boundary_list_data.bounding_box.x + boundary_list_data.bounding_box.width * 0.5;
    model.pointer_y = boundary_list_data.bounding_box.y + boundary_list_data.bounding_box.height * 0.7;
    model.pointer_down = true;
    model.pointer_pressed = true;
    _ = build(&model);
    model.pointer_pressed = false;
    model.pointer_y = boundary_list_data.bounding_box.y - 120;
    _ = build(&model);
    try std.testing.expectApproxEqAbs(
        -virtual_max_scroll,
        virtual_list_scroll.scroll_position.y,
        0.01,
    );
    try std.testing.expectApproxEqAbs(
        outer_before_boundary_drag,
        primary_scroll.scroll_position.y,
        0.01,
    );
    model.pointer_down = false;
    model.pointer_released = true;
    _ = build(&model);
    model.pointer_released = false;
    model.pointer_x = 0;
    model.pointer_y = 0;
    for (0..120) |_| _ = build(&model);
    virtual_list_scroll.scroll_position.y = 0;
    primary_scroll.scroll_position.y = -500;
    const scrolled_bounds_frame = build(&model);
    var compared_scrolled_bounds: usize = 0;
    for (scrolled_bounds_frame.semantic_nodes) |node| {
        if (node.scroll_ancestor_count == 0) continue;
        var element_id = clay.ElementId.ID("");
        element_id.id = node.element_id;
        const data = clay.getElementData(element_id);
        if (!data.found) continue;
        var expected: ?semantics.Bounds = .{
            .x = data.bounding_box.x,
            .y = data.bounding_box.y,
            .width = data.bounding_box.width,
            .height = data.bounding_box.height,
        };
        for (node.scroll_ancestor_ids[0..node.scroll_ancestor_count]) |ancestor_value| {
            var ancestor_id = clay.ElementId.ID("");
            ancestor_id.id = ancestor_value;
            const ancestor = clay.getElementData(ancestor_id);
            if (!ancestor.found or expected == null) continue;
            const current = expected.?;
            const left = @max(current.x, ancestor.bounding_box.x);
            const top = @max(current.y, ancestor.bounding_box.y);
            const right = @min(current.x + current.width, ancestor.bounding_box.x + ancestor.bounding_box.width);
            const bottom = @min(current.y + current.height, ancestor.bounding_box.y + ancestor.bounding_box.height);
            expected = if (right > left and bottom > top)
                .{ .x = left, .y = top, .width = right - left, .height = bottom - top }
            else
                null;
        }
        const expected_bounds = expected orelse semantics.Bounds{};
        try std.testing.expectApproxEqAbs(expected_bounds.x, node.bounds.x, 0.01);
        try std.testing.expectApproxEqAbs(expected_bounds.y, node.bounds.y, 0.01);
        try std.testing.expectApproxEqAbs(expected_bounds.width, node.bounds.width, 0.01);
        try std.testing.expectApproxEqAbs(expected_bounds.height, node.bounds.height, 0.01);
        compared_scrolled_bounds += 1;
    }
    try std.testing.expect(compared_scrolled_bounds > 20);
    primary_scroll.scroll_position.y = -500;
    _ = build(&model);

    state.focus_state.focus(clay.ElementId.ID("DemoTextField").id);
    const revealed_form_frame = build(&model);
    var revealed_form_bounds: ?semantics.Bounds = null;
    var primary_card_bounds: ?semantics.Bounds = null;
    for (revealed_form_frame.semantic_nodes) |node| {
        if (node.element_id == clay.ElementId.ID("DemoTextField").id) revealed_form_bounds = node.bounds;
        if (node.element_id == clay.ElementId.ID("PrimaryCard").id) primary_card_bounds = node.bounds;
    }
    try std.testing.expect(revealed_form_bounds != null and primary_card_bounds != null);
    try std.testing.expect(revealed_form_bounds.?.width > 0 and revealed_form_bounds.?.height > 0);
    try std.testing.expect(revealed_form_bounds.?.y >= primary_card_bounds.?.y);
    try std.testing.expect(
        revealed_form_bounds.?.y + revealed_form_bounds.?.height <=
            primary_card_bounds.?.y + primary_card_bounds.?.height,
    );

    model.application_name_input.submission_count = 1;
    const revealed_error_frame = build(&model);
    var revealed_error_bounds: ?semantics.Bounds = null;
    for (revealed_error_frame.semantic_nodes) |node| {
        if (node.element_id == form_field.supportingId("DemoTextField").id) {
            revealed_error_bounds = node.bounds;
        }
    }
    try std.testing.expect(revealed_error_bounds != null);
    try std.testing.expect(revealed_error_bounds.?.width > 0 and revealed_error_bounds.?.height > 0);
    try std.testing.expect(revealed_error_bounds.?.y >= primary_card_bounds.?.y);
    try std.testing.expect(
        revealed_error_bounds.?.y + revealed_error_bounds.?.height <=
            primary_card_bounds.?.y + primary_card_bounds.?.height,
    );
    model.application_name_input.submission_count = 0;
    primary_scroll.scroll_position.y = 0;
    state.focus_state.focused_id = null;
    _ = build(&model);

    model.demo_accordion_expanded_mask = 0b100;
    const switched_accordion_frame = build(&model);
    var has_old_panel = false;
    var has_new_panel = false;
    var has_new_panel_body = false;
    for (switched_accordion_frame.semantic_nodes) |node| {
        if (node.element_id == accordion.panelId("SettingsAccordion", 0).id) has_old_panel = true;
        if (node.element_id == accordion.panelId("SettingsAccordion", 2).id) has_new_panel = true;
        if (node.element_id == clay.ElementId.IDI("SettingsAccordionPanelBody", 2).id and
            std.mem.indexOf(u8, node.label, "Zig、Sokol 与 Clay") != null)
        {
            has_new_panel_body = true;
        }
    }
    try std.testing.expect(!has_old_panel);
    try std.testing.expect(has_new_panel);
    try std.testing.expect(has_new_panel_body);
    model.demo_accordion_expanded_mask = 0b001;

    model.demo_sort_expanded = true;
    model.demo_sort_index = 1;
    const expanded_select_frame = build(&model);
    var has_expanded_combo = false;
    var option_count: usize = 0;
    var checked_option_count: usize = 0;
    for (expanded_select_frame.semantic_nodes) |node| {
        if (node.role == .combo_box and node.expanded == true) has_expanded_combo = true;
        if (node.role == .option) {
            option_count += 1;
            if (node.selected and node.checked == true) checked_option_count += 1;
        }
    }
    try std.testing.expect(has_expanded_combo);
    try std.testing.expectEqual(demo_sort_items.len, option_count);
    try std.testing.expectEqual(@as(usize, 1), checked_option_count);
    model.pointer_x = 0;
    model.pointer_y = 0;
    model.pointer_pressed = true;
    const outside_press_frame = build(&model);
    var requested_select_close = false;
    for (outside_press_frame.actions) |action| {
        switch (action) {
            .demo_sort_expanded => |expanded| requested_select_close = !expanded,
            else => {},
        }
    }
    try std.testing.expect(requested_select_close);
    model.pointer_pressed = false;
    model.demo_sort_expanded = false;

    model.demo_menu_expanded = true;
    const expanded_menu_frame = build(&model);
    var has_menu_semantics = false;
    var menu_item_count: usize = 0;
    var disabled_menu_item_count: usize = 0;
    for (expanded_menu_frame.semantic_nodes) |node| {
        if (node.role == .menu) has_menu_semantics = true;
        if (node.role == .menu_item) {
            menu_item_count += 1;
            if (node.disabled) disabled_menu_item_count += 1;
        }
    }
    try std.testing.expect(has_menu_semantics);
    try std.testing.expectEqual(demo_menu_items.len, menu_item_count);
    try std.testing.expectEqual(@as(usize, 1), disabled_menu_item_count);
    model.pointer_pressed = true;
    const outside_menu_press_frame = build(&model);
    var requested_menu_close = false;
    for (outside_menu_press_frame.actions) |action| {
        switch (action) {
            .demo_menu_expanded => |expanded| requested_menu_close = !expanded,
            else => {},
        }
    }
    try std.testing.expect(requested_menu_close);
    model.pointer_pressed = false;
    model.demo_menu_expanded = false;

    model.last_native_crash = .{
        .signal_number = 11,
        .signal_code = 1,
        .architecture = .x86_64,
        .pc_in_app = true,
        .relative_pc = 0x1234,
        .absolute_pc = 0x70001234,
        .fault_address = 0,
        .process_id = 100,
        .thread_id = 101,
        .timestamp_seconds = 1_700_000_000,
    };
    model.last_native_crash.?.build_id_length = 4;
    model.last_native_crash.?.build_id[0..4].* = .{ 0x30, 0x12, 0x2a, 0x3d };
    const crash_frame = build(&model);
    var crash_text_visible = false;
    var crash_build_id_visible = false;
    for (crash_frame.semantic_nodes) |node| {
        if (node.element_id == clay.ElementId.ID("CrashDiagnosticsStatus").id and
            std.mem.indexOf(u8, node.label, "SIGSEGV") != null and
            std.mem.indexOf(u8, node.label, "libzapp+0x1234") != null)
        {
            crash_text_visible = true;
        }
        if (node.element_id == clay.ElementId.ID("CrashBuildIdStatus").id and
            std.mem.indexOf(u8, node.label, "30122a3d") != null)
        {
            crash_build_id_visible = true;
        }
    }
    try std.testing.expect(crash_text_visible);
    try std.testing.expect(crash_build_id_visible);

    const records_scroll = clay.getScrollContainerData(clay.ElementId.ID("RecordsVirtualList"));
    try std.testing.expect(records_scroll.found);
    try std.testing.expect(records_scroll.content_dimensions.h > 40_000);
    model.semantic_scroll_element_id = clay.ElementId.ID("RecordsVirtualList").id;
    model.semantic_scroll_direction = 1;
    const virtual_scrolled_frame = build(&model);
    try std.testing.expect(records_scroll.scroll_position.y < 0);
    var first_virtual_item_still_emitted = false;
    var scrolled_virtual_item_count: usize = 0;
    for (virtual_scrolled_frame.semantic_nodes) |node| {
        if (node.role == .list_item) scrolled_virtual_item_count += 1;
        if (node.element_id == virtual_list.itemId("RecordsVirtualList", 0).id) {
            first_virtual_item_still_emitted = true;
        }
    }
    try std.testing.expect(!first_virtual_item_still_emitted);
    try std.testing.expect(scrolled_virtual_item_count > 0);
    try std.testing.expect(scrolled_virtual_item_count < virtual_list.max_visible_rows);
    model.semantic_scroll_element_id = null;
    model.semantic_scroll_direction = 0;

    model.viewport_height = 1600;
    records_scroll.scroll_position.y = 0;
    state.focus_state.focus(virtual_list.itemId("RecordsVirtualList", 0).id);
    model.demo_virtual_list_selected_index = 0;
    model.focused_control_end_requested = true;
    const virtual_end_request_frame = build(&model);
    var requested_last_virtual_item = false;
    for (virtual_end_request_frame.actions) |action| {
        switch (action) {
            .demo_virtual_list_selected => |index| requested_last_virtual_item = index == 999,
            else => {},
        }
    }
    try std.testing.expect(requested_last_virtual_item);
    model.demo_virtual_list_selected_index = 999;
    model.focused_control_end_requested = false;
    const virtual_end_frame = build(&model);
    var has_last_virtual_item = false;
    var end_virtual_item_count: usize = 0;
    var end_scissor_count: usize = 0;
    var end_scissor_end_count: usize = 0;
    var end_scissor_depth: isize = 0;
    var end_scissor_min_depth: isize = 0;
    var has_embedded_virtual_scroll_bar = false;
    var end_list_bounds: ?semantics.Bounds = null;
    var last_item_bounds: ?semantics.Bounds = null;
    for (virtual_end_frame.semantic_nodes) |node| {
        if (node.role == .list_item) end_virtual_item_count += 1;
        if (node.element_id == clay.ElementId.ID("RecordsVirtualList").id) end_list_bounds = node.bounds;
        if (node.element_id == virtual_list.itemId("RecordsVirtualList", 999).id and node.selected) {
            has_last_virtual_item = true;
            last_item_bounds = node.bounds;
        }
    }
    for (virtual_end_frame.commands) |command| {
        if (command.id == clay.ElementId.ID("VirtualListScrollBar").id and
            command.command_type == .rectangle and command.z_index == 0)
        {
            has_embedded_virtual_scroll_bar = true;
        }
        if (command.command_type == .scissor_start) {
            end_scissor_count += 1;
            end_scissor_depth += 1;
        }
        if (command.command_type == .scissor_end) {
            end_scissor_end_count += 1;
            end_scissor_depth -= 1;
            end_scissor_min_depth = @min(end_scissor_min_depth, end_scissor_depth);
        }
    }
    try std.testing.expect(end_scissor_count >= 2);
    try std.testing.expectEqual(end_scissor_count, end_scissor_end_count);
    try std.testing.expectEqual(@as(isize, 0), end_scissor_depth);
    try std.testing.expectEqual(@as(isize, 0), end_scissor_min_depth);
    try std.testing.expect(has_embedded_virtual_scroll_bar);
    try std.testing.expect(end_virtual_item_count > 0);
    try std.testing.expect(has_last_virtual_item);
    try std.testing.expect(end_list_bounds != null and last_item_bounds != null);
    try std.testing.expect(last_item_bounds.?.y < end_list_bounds.?.y + end_list_bounds.?.height);
    try std.testing.expect(last_item_bounds.?.y + last_item_bounds.?.height > end_list_bounds.?.y);

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

    model.application_name_input.submission_count = 1;
    const toast_frame = build(&model);
    var has_toast_command = false;
    var has_status_semantics = false;
    var has_invalid_field_semantics = false;
    var has_form_error_status = false;
    for (toast_frame.commands) |command| {
        if (command.z_index == 200 and command.command_type == .rectangle) {
            has_toast_command = true;
            break;
        }
    }
    for (toast_frame.semantic_nodes) |node| {
        if (node.role == .status) has_status_semantics = true;
        if (node.element_id == clay.ElementId.ID("DemoTextField").id and node.required and
            node.invalid and std.mem.eql(u8, node.error_text, "应用名称至少需要 2 个字符"))
        {
            has_invalid_field_semantics = true;
        }
        if (node.element_id == form_field.supportingId("DemoTextField").id and
            node.role == .status and std.mem.eql(u8, node.label, "应用名称至少需要 2 个字符"))
        {
            has_form_error_status = true;
        }
    }
    try std.testing.expect(has_toast_command);
    try std.testing.expect(has_status_semantics);
    try std.testing.expect(has_invalid_field_semantics);
    try std.testing.expect(has_form_error_status);

    model.search_input.insertSingleLine("android");
    const filtered_frame = build(&model);
    var filtered_table_rows: ?u32 = null;
    var filtered_status = false;
    var selected_row_repaired = false;
    for (filtered_frame.semantic_nodes) |node| {
        if (node.element_id == clay.ElementId.ID("RecordsDataTable").id) {
            filtered_table_rows = node.row_count;
        }
        if (node.element_id == clay.ElementId.ID("ProjectSearchStatus").id and
            std.mem.eql(u8, node.label, "找到 1 个匹配项目"))
        {
            filtered_status = true;
        }
    }
    for (filtered_frame.actions) |action| switch (action) {
        .demo_data_table_row_selected => |row| selected_row_repaired = row == 1,
        else => {},
    };
    try std.testing.expectEqual(@as(?u32, 2), filtered_table_rows);
    try std.testing.expect(filtered_status);
    try std.testing.expect(selected_row_repaired);

    model.search_input.clear();
    model.search_input.insertSingleLine("not-present");
    state.focus_state.focus(data_table.rowId("RecordsDataTable", 1).id);
    const empty_filter_frame = build(&model);
    var empty_table_rows: ?u32 = null;
    var empty_status = false;
    var has_empty_pagination = false;
    for (empty_filter_frame.semantic_nodes) |node| {
        if (node.element_id == clay.ElementId.ID("RecordsDataTable").id) {
            empty_table_rows = node.row_count;
        }
        if (node.element_id == clay.ElementId.ID("ProjectSearchStatus").id and
            std.mem.eql(u8, node.label, "未找到匹配项目"))
        {
            empty_status = true;
        }
        if (node.element_id == clay.ElementId.ID("RecordsPagination").id) {
            has_empty_pagination = true;
        }
    }
    try std.testing.expectEqual(@as(?u32, 1), empty_table_rows);
    try std.testing.expect(empty_status);
    try std.testing.expect(!has_empty_pagination);
    try std.testing.expect(state.focus_state.isFocused(clay.ElementId.ID("ProjectSearch").id));

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

    model.demo_dialog_open = false;
    model.back_requested = false;
    model.demo_navigation_index = 1;
    const activity_page_frame = build(&model);
    var has_activity_page = false;
    var activity_item_count: usize = 0;
    var activity_has_home_content = false;
    var activity_selected_navigation_count: usize = 0;
    for (activity_page_frame.semantic_nodes) |node| {
        if (node.element_id == clay.ElementId.ID("ActivityPage").id and node.scrollable) {
            has_activity_page = true;
        }
        if (activityPageItemIndex(node.element_id) != null) activity_item_count += 1;
        if (node.element_id == clay.ElementId.ID("PrimaryCardTitle").id) activity_has_home_content = true;
        if (node.role == .navigation_item and node.selected) {
            activity_selected_navigation_count += 1;
            try std.testing.expectEqual(clay.ElementId.IDI("MainNavigation", 1).id, node.element_id);
        }
    }
    try std.testing.expect(has_activity_page);
    try std.testing.expectEqual(demo_activity_items.len, activity_item_count);
    try std.testing.expect(!activity_has_home_content);
    try std.testing.expectEqual(@as(usize, 1), activity_selected_navigation_count);
    try std.testing.expect(state.focus_state.isFocused(clay.ElementId.IDI("MainNavigation", 1).id));

    model.demo_navigation_index = 2;
    const settings_page_frame = build(&model);
    var has_settings_page = false;
    var settings_has_activity_content = false;
    var settings_has_checkbox = false;
    var settings_has_switch = false;
    var settings_radio_count: usize = 0;
    var settings_budget_radio_count: usize = 0;
    var selected_budget_radio_count: usize = 0;
    for (settings_page_frame.semantic_nodes) |node| {
        if (node.element_id == clay.ElementId.ID("SettingsPage").id and node.scrollable) {
            has_settings_page = true;
        }
        if (node.element_id == clay.ElementId.ID("ActivityPageTitle").id) settings_has_activity_content = true;
        if (node.element_id == clay.ElementId.ID("DemoCheckbox").id and node.role == .checkbox) {
            settings_has_checkbox = true;
        }
        if (node.element_id == clay.ElementId.ID("DemoSwitch").id and node.role == .switch_control) {
            settings_has_switch = true;
        }
        if (node.role == .radio_button) settings_radio_count += 1;
        if (imageCacheBudgetIndex(node.element_id) != null) {
            settings_budget_radio_count += 1;
            if (node.selected) selected_budget_radio_count += 1;
        }
    }
    try std.testing.expect(has_settings_page);
    try std.testing.expect(!settings_has_activity_content);
    try std.testing.expect(settings_has_checkbox);
    try std.testing.expect(settings_has_switch);
    try std.testing.expectEqual(demo_density_items.len + image_cache_budget_items.len, settings_radio_count);
    try std.testing.expectEqual(image_cache_budget_items.len, settings_budget_radio_count);
    try std.testing.expectEqual(@as(usize, 1), selected_budget_radio_count);
    try std.testing.expect(state.focus_state.isFocused(clay.ElementId.IDI("MainNavigation", 2).id));

    // Clay stores one global current context, so keep gesture integration in
    // this single initialized UI test instead of rebuilding a freed context.
    model.demo_navigation_index = 0;
    model.demo_floating_window_open = true;
    _ = build(&model);
    const title_data = clay.getElementData(floating_window.titleId("DemoFloatingWindow"));
    try std.testing.expect(title_data.found);
    const outer = clay.getScrollContainerData(clay.ElementId.ID("PrimaryCard"));
    try std.testing.expect(outer.found);
    const outer_before_window_drag = outer.scroll_position.y;
    const window_before_drag = state.floating_window_state.rect;
    model.pointer_x = title_data.bounding_box.x + 40;
    model.pointer_y = title_data.bounding_box.y + title_data.bounding_box.height * 0.5;
    model.pointer_down = true;
    model.pointer_pressed = true;
    _ = build(&model);
    model.pointer_pressed = false;
    model.pointer_x += 70;
    model.pointer_y += 45;
    _ = build(&model);
    try std.testing.expectApproxEqAbs(window_before_drag.x + 70, state.floating_window_state.rect.x, 0.01);
    try std.testing.expectApproxEqAbs(window_before_drag.y + 45, state.floating_window_state.rect.y, 0.01);
    try std.testing.expectApproxEqAbs(outer_before_window_drag, outer.scroll_position.y, 0.01);
    model.pointer_down = false;
    model.pointer_released = true;
    _ = build(&model);
    model.pointer_released = false;

    const resize_data = clay.getElementData(floating_window.resizeId("DemoFloatingWindow"));
    try std.testing.expect(resize_data.found);
    const window_before_resize = state.floating_window_state.rect;
    model.pointer_x = resize_data.bounding_box.x + resize_data.bounding_box.width * 0.5;
    model.pointer_y = resize_data.bounding_box.y + resize_data.bounding_box.height * 0.5;
    model.pointer_down = true;
    model.pointer_pressed = true;
    _ = build(&model);
    model.pointer_pressed = false;
    model.pointer_x += 50;
    model.pointer_y += 35;
    _ = build(&model);
    try std.testing.expect(state.floating_window_state.rect.width > window_before_resize.width + 40);
    try std.testing.expect(state.floating_window_state.rect.height > window_before_resize.height + 25);
    model.pointer_down = false;
    model.pointer_released = true;
    _ = build(&model);
    model.pointer_released = false;

    model.demo_floating_window_open = false;
    model.pointer_x = 0;
    model.pointer_y = 0;
    _ = build(&model);
    ensureElementVisibleInScrollContainer(
        layer_layout.containerId("DemoLayerLayout").id,
        clay.ElementId.ID("PrimaryCard").id,
    );
    _ = build(&model);
    const first_header = clay.getElementData(layer_layout.headerId("DemoLayerLayout", 0));
    const second_panel = clay.getElementData(layer_layout.panelId("DemoLayerLayout", 1));
    try std.testing.expect(first_header.found and second_panel.found);
    const outer_before_layer_drag = outer.scroll_position.y;
    model.pointer_x = first_header.bounding_box.x + first_header.bounding_box.width * 0.5;
    model.pointer_y = first_header.bounding_box.y + first_header.bounding_box.height * 0.5;
    model.pointer_down = true;
    model.pointer_pressed = true;
    _ = build(&model);
    model.pointer_pressed = false;
    model.pointer_x = second_panel.bounding_box.x + second_panel.bounding_box.width * 0.5;
    model.pointer_y = second_panel.bounding_box.y + 60;
    _ = build(&model);
    try std.testing.expectEqual(@as(u32, 1), state.layer_layout_state.order[0]);
    try std.testing.expectApproxEqAbs(outer_before_layer_drag, outer.scroll_position.y, 0.01);
    model.pointer_down = false;
    model.pointer_released = true;
    _ = build(&model);
    model.pointer_released = false;

    const splitter = clay.getElementData(layer_layout.splitterId("DemoLayerLayout"));
    try std.testing.expect(splitter.found);
    const ratio_before = state.layer_layout_state.split_ratio;
    model.pointer_x = splitter.bounding_box.x + splitter.bounding_box.width * 0.5;
    model.pointer_y = splitter.bounding_box.y + splitter.bounding_box.height * 0.5;
    model.pointer_down = true;
    model.pointer_pressed = true;
    _ = build(&model);
    model.pointer_pressed = false;
    model.pointer_x += 55;
    _ = build(&model);
    try std.testing.expect(state.layer_layout_state.split_ratio > ratio_before);
    try std.testing.expectApproxEqAbs(outer_before_layer_drag, outer.scroll_position.y, 0.01);
    model.pointer_down = false;
    model.pointer_released = true;
    _ = build(&model);

    // A regular interactive control follows the same press ownership rule:
    // moving outside it while held must neither scroll the parent nor click.
    model.pointer_released = false;
    model.pointer_x = 0;
    model.pointer_y = 0;
    outer.scroll_position.y = 0;
    _ = build(&model);
    const primary_button = clay.getElementData(clay.ElementId.ID("PrimaryAction"));
    const primary_card = clay.getElementData(clay.ElementId.ID("PrimaryCard"));
    try std.testing.expect(primary_button.found and primary_card.found);
    const outer_before_button_drag = outer.scroll_position.y;
    model.pointer_x = primary_button.bounding_box.x + primary_button.bounding_box.width * 0.5;
    model.pointer_y = primary_button.bounding_box.y + primary_button.bounding_box.height * 0.5;
    model.pointer_down = true;
    model.pointer_pressed = true;
    _ = build(&model);
    model.pointer_pressed = false;
    model.pointer_y = primary_card.bounding_box.y + primary_card.bounding_box.height + 100;
    _ = build(&model);
    try std.testing.expectApproxEqAbs(outer_before_button_drag, outer.scroll_position.y, 0.01);
    model.pointer_down = false;
    model.pointer_released = true;
    const button_release_frame = build(&model);
    for (button_release_frame.actions) |action| {
        try std.testing.expect(action != .primary_button_pressed);
    }
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

    actions = handleSemanticAction(
        &model,
        chip_group.itemId("StatusFilters", 1).id,
        .activate,
        "",
    );
    try std.testing.expectEqual(@as(usize, 1), actions.len);
    try std.testing.expectEqual(@as(u8, 1), actions[0].demo_filter_toggled);
    actions = handleSemanticAction(
        &model,
        chip_group.itemId("StatusFilters", 3).id,
        .activate,
        "",
    );
    try std.testing.expectEqual(@as(usize, 0), actions.len);

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
        clay.ElementId.ID("RetryStepper").id,
        .increment,
        "",
    );
    try std.testing.expectEqual(@as(usize, 1), actions.len);
    try std.testing.expectEqual(@as(i32, 4), actions[0].demo_retry_count_changed);
    model.demo_retry_count = 0;
    actions = handleSemanticAction(
        &model,
        clay.ElementId.ID("RetryStepper").id,
        .decrement,
        "",
    );
    try std.testing.expectEqual(@as(i32, 0), actions[0].demo_retry_count_changed);

    actions = handleSemanticAction(
        &model,
        clay.ElementId.ID("DemoTextField").id,
        .set_text,
        "无障碍输入",
    );
    try std.testing.expectEqual(@as(usize, 3), actions.len);
    try std.testing.expect(actions[0] == .text_input_focus_changed);
    try std.testing.expect(actions[1] == .text_select_all);
    try std.testing.expectEqualStrings("无障碍输入", actions[2].text_inserted);

    actions = handleSemanticAction(
        &model,
        clay.ElementId.ID("ProjectSearch").id,
        .set_text,
        "日志",
    );
    try std.testing.expectEqual(@as(usize, 3), actions.len);
    try std.testing.expect(actions[0].text_input_focus_changed == .search);
    try std.testing.expect(actions[1] == .text_select_all);
    try std.testing.expectEqualStrings("日志", actions[2].text_inserted);

    model.active_text_input = .search;
    actions = handleSemanticAction(
        &model,
        search_field.clearId("ProjectSearch").id,
        .activate,
        "",
    );
    try std.testing.expectEqual(@as(usize, 2), actions.len);
    try std.testing.expect(actions[0].text_input_focus_changed == .search);
    try std.testing.expect(actions[1].text_cleared == .search);

    model.active_text_input = .application_name;
    actions = handleSemanticAction(
        &model,
        clay.ElementId.ID("SubmitDemoForm").id,
        .activate,
        "",
    );
    try std.testing.expectEqual(@as(usize, 2), actions.len);
    try std.testing.expect(actions[0].text_input_focus_changed == null);
    try std.testing.expect(actions[1] == .text_submitted);
    model.active_text_input = null;

    actions = handleSemanticAction(
        &model,
        clay.ElementId.ID("ExportCrashReport").id,
        .activate,
        "",
    );
    try std.testing.expectEqual(@as(usize, 0), actions.len);
    model.last_native_crash = .{
        .signal_number = 11,
        .signal_code = 1,
        .architecture = .arm64,
        .pc_in_app = true,
        .relative_pc = 0x1234,
        .absolute_pc = 0x70001234,
        .fault_address = 0,
        .process_id = 100,
        .thread_id = 101,
        .timestamp_seconds = 1_700_000_000,
    };
    actions = handleSemanticAction(
        &model,
        clay.ElementId.ID("ExportCrashReport").id,
        .activate,
        "",
    );
    try std.testing.expectEqual(@as(usize, 1), actions.len);
    try std.testing.expect(actions[0] == .platform_crash_report_export_requested);

    actions = handleSemanticAction(
        &model,
        radio_group.itemId("DensityRadio", 2).id,
        .activate,
        "",
    );
    try std.testing.expectEqual(@as(usize, 1), actions.len);
    try std.testing.expectEqual(@as(u8, 2), actions[0].demo_density_selected);

    actions = handleSemanticAction(
        &model,
        radio_group.itemId("ImageCacheBudgetRadio", 1).id,
        .activate,
        "",
    );
    try std.testing.expectEqual(@as(usize, 1), actions.len);
    try std.testing.expectEqual(@as(u8, 2), actions[0].runtime_image_cache_budget_selected);
    model.runtime_image_cache_budget_requested = 2;
    actions = handleSemanticAction(
        &model,
        radio_group.itemId("ImageCacheBudgetRadio", 2).id,
        .activate,
        "",
    );
    try std.testing.expectEqual(@as(usize, 0), actions.len);
    model.runtime_image_cache_budget_requested = null;

    actions = handleSemanticAction(
        &model,
        select.triggerId("SortSelect").id,
        .expand,
        "",
    );
    try std.testing.expectEqual(@as(usize, 1), actions.len);
    try std.testing.expect(actions[0].demo_sort_expanded);

    model.demo_sort_expanded = true;
    actions = handleSemanticAction(
        &model,
        select.optionId("SortSelect", 2).id,
        .activate,
        "",
    );
    try std.testing.expectEqual(@as(usize, 2), actions.len);
    try std.testing.expectEqual(@as(u8, 2), actions[0].demo_sort_selected);
    try std.testing.expect(!actions[1].demo_sort_expanded);

    actions = handleSemanticAction(
        &model,
        tabs.itemId("DataTabs", 2).id,
        .activate,
        "",
    );
    try std.testing.expectEqual(@as(usize, 1), actions.len);
    try std.testing.expectEqual(@as(u8, 2), actions[0].demo_tab_selected);

    model.demo_sort_expanded = false;
    actions = handleSemanticAction(
        &model,
        menu.triggerId("ActionsMenu").id,
        .expand,
        "",
    );
    try std.testing.expectEqual(@as(usize, 1), actions.len);
    try std.testing.expect(actions[0].demo_menu_expanded);

    model.demo_menu_expanded = true;
    actions = handleSemanticAction(
        &model,
        menu.itemId("ActionsMenu", 1).id,
        .activate,
        "",
    );
    try std.testing.expectEqual(@as(usize, 1), actions.len);
    try std.testing.expectEqual(@as(u8, 1), actions[0].demo_menu_item_activated);

    actions = handleSemanticAction(
        &model,
        menu.itemId("ActionsMenu", 2).id,
        .activate,
        "",
    );
    try std.testing.expectEqual(@as(usize, 0), actions.len);

    model.demo_menu_expanded = false;
    actions = handleSemanticAction(
        &model,
        virtual_list.itemId("RecordsVirtualList", 5).id,
        .activate,
        "",
    );
    try std.testing.expectEqual(@as(usize, 1), actions.len);
    try std.testing.expectEqual(@as(u16, 5), actions[0].demo_virtual_list_selected);

    actions = handleSemanticAction(
        &model,
        clay.ElementId.ID("RecordsVirtualList").id,
        .scroll_forward,
        "",
    );
    try std.testing.expectEqual(@as(usize, 1), actions.len);
    try std.testing.expectEqual(
        clay.ElementId.ID("RecordsVirtualList").id,
        actions[0].semantic_scroll_requested.element_id,
    );

    actions = handleSemanticAction(
        &model,
        data_table.headerId("RecordsDataTable", 2).id,
        .activate,
        "",
    );
    try std.testing.expectEqual(@as(usize, 1), actions.len);
    try std.testing.expectEqual(@as(u8, 2), actions[0].demo_data_table_sorted.column_index);
    try std.testing.expect(!actions[0].demo_data_table_sorted.descending);

    actions = handleSemanticAction(
        &model,
        data_table.rowId("RecordsDataTable", 4).id,
        .activate,
        "",
    );
    try std.testing.expectEqual(@as(usize, 1), actions.len);
    try std.testing.expectEqual(@as(u8, 4), actions[0].demo_data_table_row_selected);

    actions = handleSemanticAction(
        &model,
        pagination.pageId("RecordsPagination", 0).id,
        .activate,
        "",
    );
    try std.testing.expectEqual(@as(usize, 0), actions.len);

    actions = handleSemanticAction(
        &model,
        pagination.pageId("RecordsPagination", 1).id,
        .activate,
        "",
    );
    try std.testing.expectEqual(@as(usize, 2), actions.len);
    try std.testing.expectEqual(@as(u8, 1), actions[0].demo_data_table_page_selected);
    try std.testing.expectEqual(@as(u8, 6), actions[1].demo_data_table_row_selected);

    actions = handleSemanticAction(
        &model,
        tree_view.itemId("ProjectTree", 0).id,
        .collapse,
        "",
    );
    try std.testing.expectEqual(@as(u8, 0), actions[0].demo_tree_toggled);

    actions = handleSemanticAction(
        &model,
        accordion.headerId("SettingsAccordion", 1).id,
        .activate,
        "",
    );
    try std.testing.expectEqual(@as(usize, 1), actions.len);
    try std.testing.expectEqual(@as(u64, 0b010), actions[0].demo_accordion_expanded);

    actions = handleSemanticAction(
        &model,
        accordion.headerId("SettingsAccordion", 0).id,
        .collapse,
        "",
    );
    try std.testing.expectEqual(@as(usize, 1), actions.len);
    try std.testing.expectEqual(@as(u64, 0), actions[0].demo_accordion_expanded);

    actions = handleSemanticAction(
        &model,
        accordion.headerId("SettingsAccordion", 2).id,
        .expand,
        "",
    );
    try std.testing.expectEqual(@as(usize, 1), actions.len);
    try std.testing.expectEqual(@as(u64, 0b100), actions[0].demo_accordion_expanded);

    model.demo_accordion_expanded_mask = 0b100;
    actions = handleSemanticAction(
        &model,
        accordion.headerId("SettingsAccordion", 2).id,
        .expand,
        "",
    );
    try std.testing.expectEqual(@as(usize, 0), actions.len);

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

    actions = handleSemanticAction(
        &model,
        clay.ElementId.ID("LoadRuntimeImage").id,
        .activate,
        "",
    );
    try std.testing.expectEqual(@as(usize, 1), actions.len);
    try std.testing.expect(actions[0] == .platform_runtime_image_load_requested);

    model.runtime_image_load_pending = true;
    actions = handleSemanticAction(
        &model,
        clay.ElementId.ID("LoadRuntimeImage").id,
        .activate,
        "",
    );
    try std.testing.expectEqual(@as(usize, 1), actions.len);
    try std.testing.expect(actions[0] == .platform_runtime_image_load_cancel_requested);
    model.runtime_image_load_pending = false;

    model.runtime_image_cached_count = 1;
    actions = handleSemanticAction(
        &model,
        clay.ElementId.ID("ClearRuntimeImageCache").id,
        .activate,
        "",
    );
    try std.testing.expectEqual(@as(usize, 1), actions.len);
    try std.testing.expectEqual(
        runtime_image.ClearReason.manual,
        actions[0].runtime_image_cache_clear_requested,
    );

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

test "demo form validation waits for submission and accepts two characters" {
    var model: Model = .{};
    try std.testing.expect(!demoTextInvalid(&model));
    model.application_name_input.submission_count = 1;
    try std.testing.expect(demoTextInvalid(&model));
    @memcpy(model.application_name_input.buffer[0.."应用".len], "应用");
    model.application_name_input.length = "应用".len;
    try std.testing.expect(!demoTextInvalid(&model));
}

test "data table sorting preserves stable row identities" {
    const ascending = demoTableOrder(0, false);
    try std.testing.expectEqual(@as(usize, 2), ascending[0]);
    try std.testing.expectEqual(@as(usize, 17), ascending[ascending.len - 1]);
    const descending = demoTableOrder(0, true);
    try std.testing.expectEqual(@as(usize, 17), descending[0]);
    try std.testing.expectEqual(@as(usize, 2), descending[descending.len - 1]);
    try std.testing.expectEqualStrings("虚拟列表", demoTableCell(4, 1));
    try std.testing.expectEqual(@as(usize, 0), demoTablePageForRow(&ascending, 0));
    try std.testing.expectEqual(@as(usize, 2), demoTablePageForRow(&descending, 0));
}

test "data table search filters every column without losing sort order" {
    const android = demoTableFilteredOrder(0, false, "android");
    try std.testing.expectEqual(@as(usize, 1), android.count);
    try std.testing.expectEqual(@as(usize, 1), android.items()[0]);

    const completed = demoTableFilteredOrder(0, false, " 已完成 ");
    try std.testing.expect(completed.count > 1);
    for (completed.items()[1..], 1..) |row_index, display_index| {
        try std.testing.expect(demoTableRowBefore(
            completed.items()[display_index - 1],
            row_index,
            0,
            false,
        ));
        try std.testing.expectEqualStrings("已完成", demo_table_rows[row_index].status);
    }

    const chinese = demoTableFilteredOrder(0, false, "输入法");
    try std.testing.expectEqual(@as(usize, 1), chinese.count);
    try std.testing.expectEqualStrings("输入法桥", demo_table_rows[chinese.items()[0]].name);

    const missing = demoTableFilteredOrder(0, false, "not-present");
    try std.testing.expectEqual(@as(usize, 0), missing.count);
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

test "runtime image status reports bounds progress and dimensions" {
    var model: Model = .{
        .file_size = 12_266,
        .file_size_known = true,
        .runtime_image_load_pending = true,
        .runtime_image_bytes_received = 4096,
        .runtime_image_cached_count = 1,
    };
    var buffer: [320]u8 = undefined;
    const progress = formatRuntimeImageStatus(&buffer, &model);
    try std.testing.expect(std.mem.indexOf(u8, progress, "4096 / 12266") != null);

    model.runtime_image_load_pending = false;
    model.runtime_image_loaded = true;
    model.runtime_image_width = 128;
    model.runtime_image_height = 64;
    model.runtime_image_bytes_received = 12_266;
    const loaded = formatRuntimeImageStatus(&buffer, &model);
    try std.testing.expect(std.mem.indexOf(u8, loaded, "128 × 64") != null);
    try std.testing.expect(std.mem.indexOf(u8, loaded, "缓存新增（1/4）") != null);

    model.runtime_image_cache_hit = true;
    const cache_hit = formatRuntimeImageStatus(&buffer, &model);
    try std.testing.expect(std.mem.indexOf(u8, cache_hit, "缓存命中（1/4）") != null);

    model.runtime_image_loaded = false;
    model.file_size = runtime_image.max_encoded_bytes + 1;
    const oversized = formatRuntimeImageStatus(&buffer, &model);
    try std.testing.expect(std.mem.indexOf(u8, oversized, "16 MiB") != null);

    model.file_size = 0;
    model.file_size_known = false;
    model.last_runtime_image_cache_clear_reason = .memory_pressure;
    model.last_runtime_image_cache_released_count = 1;
    const released = formatRuntimeImageStatus(&buffer, &model);
    try std.testing.expect(std.mem.indexOf(u8, released, "系统内存压力") != null);
    try std.testing.expect(std.mem.indexOf(u8, released, "1 个动态槽") != null);

    model.last_runtime_image_cache_clear_reason = null;
    model.runtime_image_cache_budget = 2;
    model.last_runtime_image_budget_released_count = 2;
    const budget = formatRuntimeImageStatus(&buffer, &model);
    try std.testing.expect(std.mem.indexOf(u8, budget, "调整为 2 槽") != null);
    try std.testing.expect(std.mem.indexOf(u8, budget, "淘汰 2 个") != null);
}
