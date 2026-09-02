const std = @import("std");
const builtin = @import("builtin");
const semantics = @import("../ui/semantics.zig");

pub const max_payload_bytes = 4096;
pub const max_file_display_name_bytes = 256;
pub const max_file_mime_type_bytes = 128;
pub const max_accessibility_nodes = semantics.max_nodes;
pub const max_accessibility_text_bytes = 128;
pub const max_crash_build_id_bytes = 20;

pub const AccessibilityAction = enum(c_int) {
    focus = 1,
    click = 2,
    increment = 3,
    decrement = 4,
    set_text = 5,
    expand = 6,
    collapse = 7,
    scroll_forward = 8,
    scroll_backward = 9,
};

pub const AccessibilityNode = extern struct {
    element_id: u32,
    role_value: c_int,
    flags: u32,
    x: f32,
    y: f32,
    width: f32,
    height: f32,
    value: f32,
    value_min: f32,
    value_max: f32,
    value_step: f32,
    level: u16,
    row_index: u16,
    column_index: u16,
    row_span: u16,
    column_span: u16,
    row_count: u16,
    column_count: u16,
    label_length: u16,
    value_text_length: u16,
    error_text_length: u16,
    label: [max_accessibility_text_bytes]u8,
    value_text: [max_accessibility_text_bytes]u8,
    error_text: [max_accessibility_text_bytes]u8,
};

const accessibility_flag_checked_present: u32 = 1 << 0;
const accessibility_flag_checked: u32 = 1 << 1;
const accessibility_flag_disabled: u32 = 1 << 2;
const accessibility_flag_focused: u32 = 1 << 3;
const accessibility_flag_selected: u32 = 1 << 4;
const accessibility_flag_modal: u32 = 1 << 5;
const accessibility_flag_expanded_present: u32 = 1 << 6;
const accessibility_flag_expanded: u32 = 1 << 7;
const accessibility_flag_scrollable: u32 = 1 << 8;
const accessibility_flag_can_scroll_forward: u32 = 1 << 9;
const accessibility_flag_can_scroll_backward: u32 = 1 << 10;
const accessibility_flag_required: u32 = 1 << 11;
const accessibility_flag_invalid: u32 = 1 << 12;

var last_accessibility_hash: ?u64 = null;

comptime {
    std.debug.assert(@sizeOf(Event) == 4592);
    std.debug.assert(@sizeOf(AccessibilityNode) == 448);
}

pub const EventKind = enum(c_int) {
    composition_changed = 1,
    composition_committed = 2,
    composition_cancelled = 3,
    backspace = 4,
    submit = 5,
    permission_result = 6,
    file_selected = 7,
    file_selection_cancelled = 8,
    accessibility_action = 9,
    file_read_completed = 10,
    file_read_failed = 11,
    file_stream_chunk = 12,
    file_stream_completed = 13,
    file_stream_failed = 14,
    file_stream_cancelled = 15,
    native_crash_recovered = 16,
    crash_report_export_result = 17,
    navigation_requested = 18,
    memory_pressure = 19,
};

pub const Event = extern struct {
    kind_value: c_int,
    detail_value: c_int,
    request_id: u64,
    count: u32,
    element_id: u32,
    action_value: c_int,
    granted: bool,
    truncated: bool,
    reserved: [2]u8,
    text_length: usize,
    text_buffer: [max_payload_bytes]u8,
    file_size: u64,
    display_name_length: u16,
    mime_type_length: u16,
    file_size_known: bool,
    metadata_reserved: [3]u8,
    display_name_buffer: [max_file_display_name_bytes]u8,
    mime_type_buffer: [max_file_mime_type_bytes]u8,
    crash_absolute_pc: u64,
    crash_timestamp_seconds: i64,
    crash_process_id: i32,
    crash_thread_id: i32,
    crash_architecture: u32,
    crash_flags: u32,
    crash_build_id_length: u8,
    crash_build_id: [max_crash_build_id_bytes]u8,
    crash_reserved: [3]u8,

    pub fn kind(self: *const Event) ?EventKind {
        return switch (self.kind_value) {
            @intFromEnum(EventKind.composition_changed) => .composition_changed,
            @intFromEnum(EventKind.composition_committed) => .composition_committed,
            @intFromEnum(EventKind.composition_cancelled) => .composition_cancelled,
            @intFromEnum(EventKind.backspace) => .backspace,
            @intFromEnum(EventKind.submit) => .submit,
            @intFromEnum(EventKind.permission_result) => .permission_result,
            @intFromEnum(EventKind.file_selected) => .file_selected,
            @intFromEnum(EventKind.file_selection_cancelled) => .file_selection_cancelled,
            @intFromEnum(EventKind.accessibility_action) => .accessibility_action,
            @intFromEnum(EventKind.file_read_completed) => .file_read_completed,
            @intFromEnum(EventKind.file_read_failed) => .file_read_failed,
            @intFromEnum(EventKind.file_stream_chunk) => .file_stream_chunk,
            @intFromEnum(EventKind.file_stream_completed) => .file_stream_completed,
            @intFromEnum(EventKind.file_stream_failed) => .file_stream_failed,
            @intFromEnum(EventKind.file_stream_cancelled) => .file_stream_cancelled,
            @intFromEnum(EventKind.native_crash_recovered) => .native_crash_recovered,
            @intFromEnum(EventKind.crash_report_export_result) => .crash_report_export_result,
            @intFromEnum(EventKind.navigation_requested) => .navigation_requested,
            @intFromEnum(EventKind.memory_pressure) => .memory_pressure,
            else => null,
        };
    }

    pub fn text(self: *const Event) []const u8 {
        return self.payload();
    }

    pub fn payload(self: *const Event) []const u8 {
        return self.text_buffer[0..@min(self.text_length, self.text_buffer.len)];
    }

    pub fn displayName(self: *const Event) []const u8 {
        const length = @min(@as(usize, self.display_name_length), self.display_name_buffer.len);
        return self.display_name_buffer[0..length];
    }

    pub fn mimeType(self: *const Event) []const u8 {
        const length = @min(@as(usize, self.mime_type_length), self.mime_type_buffer.len);
        return self.mime_type_buffer[0..length];
    }

    pub fn fileSize(self: *const Event) ?u64 {
        return if (self.file_size_known) self.file_size else null;
    }
};

extern fn zapp_android_bridge_attach(activity: ?*const anyopaque) void;
extern fn zapp_android_bridge_set_ime_visible(visible: bool) void;
extern fn zapp_android_bridge_request_permission(request_id: u64, permission: c_int) bool;
extern fn zapp_android_bridge_open_file(request_id: u64) bool;
extern fn zapp_android_bridge_read_file(request_id: u64, uri: [*]const u8, uri_length: usize, max_bytes: u32) bool;
extern fn zapp_android_bridge_stream_file(request_id: u64, uri: [*]const u8, uri_length: usize, chunk_bytes: u32) bool;
extern fn zapp_android_bridge_cancel_file_stream(request_id: u64) bool;
extern fn zapp_android_bridge_share_crash_report(request_id: u64, text: [*]const u8, text_length: usize) bool;
extern fn zapp_android_bridge_update_accessibility(nodes: [*]const AccessibilityNode, count: usize) void;
extern fn zapp_android_bridge_poll(event: *Event) bool;
extern fn zapp_android_bridge_reset() void;

pub fn attach(activity: ?*const anyopaque) void {
    if (comptime builtin.abi.isAndroid()) zapp_android_bridge_attach(activity);
}

pub fn setImeVisible(visible: bool) void {
    if (comptime builtin.abi.isAndroid()) zapp_android_bridge_set_ime_visible(visible);
}

pub fn requestPermission(request_id: u64, permission: c_int) bool {
    if (comptime builtin.abi.isAndroid()) {
        return zapp_android_bridge_request_permission(request_id, permission);
    }
    return false;
}

pub fn openFile(request_id: u64) bool {
    if (comptime builtin.abi.isAndroid()) return zapp_android_bridge_open_file(request_id);
    return false;
}

pub fn readFile(request_id: u64, uri: []const u8, max_bytes: u32) bool {
    if (comptime builtin.abi.isAndroid()) {
        return zapp_android_bridge_read_file(request_id, uri.ptr, uri.len, max_bytes);
    }
    return false;
}

pub fn streamFile(request_id: u64, uri: []const u8, chunk_bytes: u32) bool {
    if (comptime builtin.abi.isAndroid()) {
        return zapp_android_bridge_stream_file(request_id, uri.ptr, uri.len, chunk_bytes);
    }
    return false;
}

pub fn cancelFileStream(request_id: u64) bool {
    if (comptime builtin.abi.isAndroid()) return zapp_android_bridge_cancel_file_stream(request_id);
    return false;
}

pub fn shareCrashReport(request_id: u64, text: []const u8) bool {
    if (comptime builtin.abi.isAndroid()) {
        return zapp_android_bridge_share_crash_report(request_id, text.ptr, text.len);
    }
    return false;
}

pub fn updateAccessibility(nodes: []const semantics.Node) void {
    if (comptime !builtin.abi.isAndroid()) return;

    var native_nodes: [max_accessibility_nodes]AccessibilityNode = undefined;
    const count = @min(nodes.len, native_nodes.len);
    for (nodes[0..count], 0..) |node, index| native_nodes[index] = serializeAccessibilityNode(node);

    var hasher = std.hash.Wyhash.init(0);
    hasher.update(std.mem.asBytes(&count));
    hasher.update(std.mem.sliceAsBytes(native_nodes[0..count]));
    const hash = hasher.final();
    if (last_accessibility_hash == hash) return;
    last_accessibility_hash = hash;
    zapp_android_bridge_update_accessibility(&native_nodes, count);
}

pub fn poll(event: *Event) bool {
    if (comptime builtin.abi.isAndroid()) return zapp_android_bridge_poll(event);
    return false;
}

pub fn reset() void {
    last_accessibility_hash = null;
    if (comptime builtin.abi.isAndroid()) zapp_android_bridge_reset();
}

fn serializeAccessibilityNode(node: semantics.Node) AccessibilityNode {
    var result: AccessibilityNode = .{
        .element_id = node.element_id,
        .role_value = @intFromEnum(node.role),
        .flags = 0,
        .x = node.bounds.x,
        .y = node.bounds.y,
        .width = node.bounds.width,
        .height = node.bounds.height,
        .value = node.value orelse std.math.nan(f32),
        .value_min = node.value_min,
        .value_max = node.value_max,
        .value_step = node.value_step,
        .level = node.level,
        .row_index = node.row_index,
        .column_index = node.column_index,
        .row_span = node.row_span,
        .column_span = node.column_span,
        .row_count = node.row_count,
        .column_count = node.column_count,
        .label_length = 0,
        .value_text_length = 0,
        .error_text_length = 0,
        .label = @splat(0),
        .value_text = @splat(0),
        .error_text = @splat(0),
    };
    if (node.checked) |checked| {
        result.flags |= accessibility_flag_checked_present;
        if (checked) result.flags |= accessibility_flag_checked;
    }
    if (node.disabled) result.flags |= accessibility_flag_disabled;
    if (node.focused) result.flags |= accessibility_flag_focused;
    if (node.selected) result.flags |= accessibility_flag_selected;
    if (node.modal) result.flags |= accessibility_flag_modal;
    if (node.expanded) |expanded| {
        result.flags |= accessibility_flag_expanded_present;
        if (expanded) result.flags |= accessibility_flag_expanded;
    }
    if (node.scrollable) result.flags |= accessibility_flag_scrollable;
    if (node.can_scroll_forward) result.flags |= accessibility_flag_can_scroll_forward;
    if (node.can_scroll_backward) result.flags |= accessibility_flag_can_scroll_backward;
    if (node.required) result.flags |= accessibility_flag_required;
    if (node.invalid) result.flags |= accessibility_flag_invalid;
    result.label_length = @intCast(copyUtf8Prefix(&result.label, node.label));
    result.value_text_length = @intCast(copyUtf8Prefix(&result.value_text, node.value_text));
    result.error_text_length = @intCast(copyUtf8Prefix(&result.error_text, node.error_text));
    return result;
}

fn copyUtf8Prefix(destination: []u8, source: []const u8) usize {
    var length = @min(destination.len, source.len);
    while (length > 0 and length < source.len and source[length] & 0xc0 == 0x80) length -= 1;
    @memcpy(destination[0..length], source[0..length]);
    return length;
}

test "native event exposes request metadata and bounded payload" {
    var event: Event = .{
        .kind_value = @intFromEnum(EventKind.file_selected),
        .detail_value = 0,
        .request_id = 42,
        .count = 0,
        .element_id = 0,
        .action_value = 0,
        .granted = false,
        .truncated = false,
        .reserved = @splat(0),
        .text_length = 3,
        .text_buffer = @splat(0),
        .file_size = 74,
        .display_name_length = 0,
        .mime_type_length = 0,
        .file_size_known = true,
        .metadata_reserved = @splat(0),
        .display_name_buffer = @splat(0),
        .mime_type_buffer = @splat(0),
        .crash_absolute_pc = 0,
        .crash_timestamp_seconds = 0,
        .crash_process_id = 0,
        .crash_thread_id = 0,
        .crash_architecture = 0,
        .crash_flags = 0,
        .crash_build_id_length = 0,
        .crash_build_id = @splat(0),
        .crash_reserved = @splat(0),
    };
    @memcpy(event.text_buffer[0..3], "abc");
    @memcpy(event.display_name_buffer[0..10], "中文.txt");
    event.display_name_length = 10;
    @memcpy(event.mime_type_buffer[0..10], "text/plain");
    event.mime_type_length = 10;
    try std.testing.expectEqual(EventKind.file_selected, event.kind().?);
    try std.testing.expectEqual(@as(u64, 42), event.request_id);
    try std.testing.expectEqualStrings("abc", event.text());
    try std.testing.expectEqualStrings("中文.txt", event.displayName());
    try std.testing.expectEqualStrings("text/plain", event.mimeType());
    try std.testing.expectEqual(@as(?u64, 74), event.fileSize());

    event.kind_value = 99;
    try std.testing.expect(event.kind() == null);
    event.text_length = max_payload_bytes + 100;
    try std.testing.expectEqual(max_payload_bytes, event.payload().len);
    event.display_name_length = max_file_display_name_bytes + 1;
    try std.testing.expectEqual(max_file_display_name_bytes, event.displayName().len);
}

test "native navigation event kind remains ABI-stable" {
    var event: Event = std.mem.zeroes(Event);
    event.kind_value = @intFromEnum(EventKind.navigation_requested);
    event.detail_value = @intFromEnum(@import("platform.zig").NavigationCommand.left);
    try std.testing.expectEqual(EventKind.navigation_requested, event.kind().?);
    try std.testing.expectEqual(@as(c_int, 8), event.detail_value);
    try std.testing.expectEqual(@as(c_int, 11), @intFromEnum(@import("platform.zig").NavigationCommand.last));
}

test "memory pressure event kind remains ABI-stable" {
    var event: Event = std.mem.zeroes(Event);
    event.kind_value = @intFromEnum(EventKind.memory_pressure);
    event.detail_value = 10;
    try std.testing.expectEqual(EventKind.memory_pressure, event.kind().?);
    try std.testing.expectEqual(@as(c_int, 19), @intFromEnum(EventKind.memory_pressure));
    try std.testing.expectEqual(@as(c_int, 10), event.detail_value);
}

test "extended accessibility roles remain ABI-stable" {
    try std.testing.expectEqual(@as(c_int, 23), @intFromEnum(semantics.Role.list_item));
    try std.testing.expectEqual(@as(c_int, 24), @intFromEnum(semantics.Role.table));
    try std.testing.expectEqual(@as(c_int, 25), @intFromEnum(semantics.Role.row));
    try std.testing.expectEqual(@as(c_int, 26), @intFromEnum(semantics.Role.column_header));
    try std.testing.expectEqual(@as(c_int, 27), @intFromEnum(semantics.Role.chip));
    try std.testing.expectEqual(@as(c_int, 28), @intFromEnum(semantics.Role.spin_button));
}

test "accessibility serialization preserves numeric range metadata" {
    const node = serializeAccessibilityNode(.{
        .element_id = 12,
        .role = .spin_button,
        .label = "重试次数",
        .value_text = "4",
        .value = 4,
        .value_min = 0,
        .value_max = 10,
        .value_step = 2,
    });
    try std.testing.expectEqual(@as(f32, 4), node.value);
    try std.testing.expectEqual(@as(f32, 0), node.value_min);
    try std.testing.expectEqual(@as(f32, 10), node.value_max);
    try std.testing.expectEqual(@as(f32, 2), node.value_step);
}

test "accessibility serialization preserves collection metadata" {
    const node = serializeAccessibilityNode(.{
        .element_id = 9,
        .role = .row,
        .label = "Z-104，中文字体，已完成",
        .selected = true,
        .row_index = 2,
        .column_index = 0,
        .row_span = 1,
        .column_span = 4,
        .row_count = 7,
        .column_count = 4,
    });
    try std.testing.expectEqual(@as(u16, 2), node.row_index);
    try std.testing.expectEqual(@as(u16, 4), node.column_span);
    try std.testing.expectEqual(@as(u16, 7), node.row_count);
    try std.testing.expectEqual(@as(u16, 4), node.column_count);
}

test "accessibility serialization preserves flags bounds and UTF-8 boundaries" {
    const node = serializeAccessibilityNode(.{
        .element_id = 7,
        .role = .checkbox,
        .label = "中文按钮",
        .checked = true,
        .focused = true,
        .bounds = .{ .x = 10, .y = 20, .width = 30, .height = 40 },
    });
    try std.testing.expectEqual(@as(u32, 7), node.element_id);
    try std.testing.expect(node.flags & accessibility_flag_checked_present != 0);
    try std.testing.expect(node.flags & accessibility_flag_checked != 0);
    try std.testing.expect(node.flags & accessibility_flag_focused != 0);
    try std.testing.expectEqual(@as(f32, 30), node.width);
    try std.testing.expectEqualStrings("中文按钮", node.label[0..node.label_length]);
}

test "accessibility serialization preserves form validation metadata" {
    const node = serializeAccessibilityNode(.{
        .element_id = 11,
        .role = .text_field,
        .label = "应用名称",
        .required = true,
        .invalid = true,
        .error_text = "应用名称至少需要 2 个字符",
    });
    try std.testing.expect(node.flags & accessibility_flag_required != 0);
    try std.testing.expect(node.flags & accessibility_flag_invalid != 0);
    try std.testing.expectEqualStrings(
        "应用名称至少需要 2 个字符",
        node.error_text[0..node.error_text_length],
    );
}

test "accessibility serialization exposes available scroll directions" {
    const node = serializeAccessibilityNode(.{
        .element_id = 8,
        .role = .list,
        .label = "最近活动",
        .scrollable = true,
        .can_scroll_forward = true,
        .can_scroll_backward = false,
    });

    try std.testing.expect(node.flags & accessibility_flag_scrollable != 0);
    try std.testing.expect(node.flags & accessibility_flag_can_scroll_forward != 0);
    try std.testing.expect(node.flags & accessibility_flag_can_scroll_backward == 0);
}
