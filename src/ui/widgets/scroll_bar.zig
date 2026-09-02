const std = @import("std");
const clay = @import("zclay");
const interaction = @import("interaction.zig");
const theme = @import("../theme.zig");

pub const State = struct {
    active_id: ?u32 = null,
    grab_offset: f32 = 0,
};

pub const Config = struct {
    id: []const u8,
    scroll_id: []const u8,
    width: f32 = 14,
    inset: f32 = 8,
    min_thumb_height: f32 = 36,
    z_index: i16 = 40,
    presentation: Presentation = .floating,
};

pub const Presentation = enum {
    floating,
    embedded,
};

const Metrics = struct {
    track_height: f32,
    thumb_height: f32,
    thumb_top: f32,
    travel: f32,
    max_scroll: f32,
};

/// Draws an overlay scrollbar attached to the current Clay parent. The scroll
/// data comes from the previous completed layout, matching Clay's own input
/// update model. Clicking the rail pages directly to that position; dragging
/// the thumb can reach both exact endpoints.
pub fn draw(state: *State, input: interaction.Input, config: Config) void {
    const scroll = clay.getScrollContainerData(clay.ElementId.ID(config.scroll_id));
    if (!scroll.found or !scroll.config.vertical) return;

    const metrics = calculateMetrics(
        scroll.content_dimensions.h,
        scroll.scroll_container_dimensions.h,
        scroll.scroll_position.y,
        config.inset,
        config.min_thumb_height,
    );
    if (metrics.max_scroll <= 0 or metrics.track_height <= 0) {
        if (state.active_id == clay.ElementId.ID(config.id).id) state.active_id = null;
        return;
    }

    const track_id = clay.ElementId.ID(config.id);
    const track_data = clay.getElementData(track_id);
    const hovered = track_data.found and pointInside(input.x, input.y, track_data.bounding_box);
    if (input.pressed and hovered and track_data.found) {
        state.active_id = track_id.id;
        const local_y = input.y - track_data.bounding_box.y;
        if (local_y >= metrics.thumb_top and local_y <= metrics.thumb_top + metrics.thumb_height) {
            state.grab_offset = local_y - metrics.thumb_top;
        } else {
            state.grab_offset = metrics.thumb_height * 0.5;
        }
    }
    if (state.active_id == track_id.id and input.down and track_data.found) {
        const requested_top = input.y - track_data.bounding_box.y - state.grab_offset;
        scroll.scroll_position.y = scrollPositionForThumb(requested_top, metrics);
    }
    if (state.active_id == track_id.id and input.released) state.active_id = null;

    const current = calculateMetrics(
        scroll.content_dimensions.h,
        scroll.scroll_container_dimensions.h,
        scroll.scroll_position.y,
        config.inset,
        config.min_thumb_height,
    );
    const track_declaration: clay.ElementDeclaration = if (config.presentation == .floating) .{
        .id = track_id,
        .layout = .{
            .sizing = .{ .w = .fixed(config.width), .h = .fixed(current.track_height) },
            .direction = .top_to_bottom,
        },
        .background_color = .{ 8, 15, 27, 150 },
        .corner_radius = .all(config.width * 0.5),
        .floating = .{
            .offset = .{ .x = -config.inset, .y = config.inset },
            .z_index = config.z_index,
            .attach_points = .{ .element = .right_top, .parent = .right_top },
            .pointer_capture_mode = .capture,
            .attach_to = .to_parent,
            .clip_to = .to_attached_parent,
        },
    } else .{
        .id = track_id,
        .layout = .{
            .sizing = .{ .w = .fixed(config.width), .h = .fixed(current.track_height) },
            .direction = .top_to_bottom,
        },
        .background_color = .{ 8, 15, 27, 150 },
        .corner_radius = .all(config.width * 0.5),
    };
    clay.UI()(track_declaration)({
        if (config.presentation == .embedded and current.thumb_top > 0) {
            clay.UI()(.{
                .layout = .{
                    .sizing = .{ .w = .grow, .h = .fixed(current.thumb_top) },
                },
            })({});
        }
        const thumb_declaration: clay.ElementDeclaration = if (config.presentation == .floating) .{
            .layout = .{
                .sizing = .{ .w = .grow, .h = .fixed(current.thumb_height) },
            },
            .background_color = if (state.active_id == track_id.id)
                theme.controls.focus
            else if (hovered)
                theme.controls.text_secondary
            else
                .{ 97, 121, 157, 220 },
            .corner_radius = .all(config.width * 0.5),
            .floating = .{
                .offset = .{ .x = 0, .y = current.thumb_top },
                .z_index = config.z_index + 1,
                .attach_points = .{ .element = .left_top, .parent = .left_top },
                .pointer_capture_mode = .passthrough,
                .attach_to = .to_parent,
                .clip_to = .to_attached_parent,
            },
        } else .{
            .layout = .{
                .sizing = .{ .w = .grow, .h = .fixed(current.thumb_height) },
            },
            .background_color = if (state.active_id == track_id.id)
                theme.controls.focus
            else if (hovered)
                theme.controls.text_secondary
            else
                .{ 97, 121, 157, 220 },
            .corner_radius = .all(config.width * 0.5),
        };
        clay.UI()(thumb_declaration)({});
    });
}

fn pointInside(x: f32, y: f32, bounds: clay.BoundingBox) bool {
    return x >= bounds.x and x <= bounds.x + bounds.width and
        y >= bounds.y and y <= bounds.y + bounds.height;
}

fn calculateMetrics(
    content_height: f32,
    viewport_height: f32,
    scroll_y: f32,
    inset: f32,
    min_thumb_height: f32,
) Metrics {
    const track_height = @max(viewport_height - inset * 2, 0);
    const max_scroll = @max(content_height - viewport_height, 0);
    const thumb_height = if (content_height <= 0)
        track_height
    else
        @min(track_height, @max(track_height * viewport_height / content_height, min_thumb_height));
    const travel = @max(track_height - thumb_height, 0);
    const progress = if (max_scroll <= 0) 0 else @min(@max(-scroll_y / max_scroll, 0), 1);
    return .{
        .track_height = track_height,
        .thumb_height = thumb_height,
        .thumb_top = travel * progress,
        .travel = travel,
        .max_scroll = max_scroll,
    };
}

fn scrollPositionForThumb(requested_top: f32, metrics: Metrics) f32 {
    if (metrics.travel <= 0 or metrics.max_scroll <= 0) return 0;
    const progress = @min(@max(requested_top / metrics.travel, 0), 1);
    return -metrics.max_scroll * progress;
}

test "scrollbar metrics map both exact endpoints" {
    const top = calculateMetrics(3184, 684, 0, 8, 36);
    try std.testing.expectEqual(@as(f32, 2500), top.max_scroll);
    try std.testing.expectEqual(@as(f32, 0), top.thumb_top);
    try std.testing.expectEqual(@as(f32, 0), scrollPositionForThumb(-100, top));
    try std.testing.expectEqual(@as(f32, -2500), scrollPositionForThumb(top.travel + 100, top));

    const bottom = calculateMetrics(3184, 684, -2500, 8, 36);
    try std.testing.expectApproxEqAbs(bottom.travel, bottom.thumb_top, 0.001);
}

test "scrollbar hides when content fits viewport" {
    const metrics = calculateMetrics(500, 684, 0, 8, 36);
    try std.testing.expectEqual(@as(f32, 0), metrics.max_scroll);
    try std.testing.expectEqual(metrics.track_height, metrics.thumb_height);
}
