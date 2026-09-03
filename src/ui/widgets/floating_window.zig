const std = @import("std");
const clay = @import("zclay");
const interaction = @import("interaction.zig");
const label = @import("label.zig");
const semantics = @import("../semantics.zig");
const theme = @import("../theme.zig");

pub const DrawContentFn = *const fn (context: ?*anyopaque) void;

pub const Rect = struct {
    x: f32 = 96,
    y: f32 = 72,
    width: f32 = 420,
    height: f32 = 280,
};

pub const State = struct {
    rect: Rect = .{},
    mode: Mode = .none,
    pointer_origin: clay.Vector2 = .{ .x = 0, .y = 0 },
    rect_origin: Rect = .{},
    close_active: bool = false,

    pub const Mode = enum {
        none,
        moving,
        resizing,
    };
};

pub const Config = struct {
    id: []const u8,
    title: []const u8,
    viewport_width: f32,
    viewport_height: f32,
    min_width: f32 = 260,
    min_height: f32 = 180,
    title_height: f32 = 44,
    resize_handle_size: f32 = 22,
    z_index: i16 = 60,
    input_enabled: bool = true,
    focused_id: ?u32 = null,
    draw_content: ?DrawContentFn = null,
    content_context: ?*anyopaque = null,
    semantic_registry: ?*semantics.Registry = null,
};

pub const Result = struct {
    close_requested: bool = false,
    close_focus_requested: bool = false,
    activated: bool = false,
    interacting: bool = false,
    rect_changed: bool = false,
};

pub fn panelId(id: []const u8) clay.ElementId {
    return clay.ElementId.ID(id);
}

pub fn titleId(id: []const u8) clay.ElementId {
    return clay.ElementId.IDI(id, 1);
}

pub fn closeId(id: []const u8) clay.ElementId {
    return clay.ElementId.IDI(id, 2);
}

pub fn resizeId(id: []const u8) clay.ElementId {
    return clay.ElementId.IDI(id, 3);
}

pub fn claimsPointer(state: *const State, input: interaction.Input, id: []const u8) bool {
    if (state.mode != .none or state.close_active) return true;
    if (!input.pressed) return false;
    return pointerInsideElement(input, titleId(id)) or
        pointerInsideElement(input, resizeId(id)) or
        pointerInsideElement(input, closeId(id));
}

pub fn draw(state: *State, input: interaction.Input, config: Config) Result {
    var result: Result = .{};
    state.rect = clampRect(state.rect, config);

    const panel_data = clay.getElementData(panelId(config.id));
    const title_hovered = pointerInsideElement(input, titleId(config.id));
    const close_hovered = pointerInsideElement(input, closeId(config.id));
    const resize_hovered = pointerInsideElement(input, resizeId(config.id));
    if (config.input_enabled and input.pressed) {
        result.activated = panel_data.found and pointInside(input.x, input.y, panel_data.bounding_box);
        if (close_hovered) {
            state.close_active = true;
            result.close_focus_requested = true;
        } else if (resize_hovered) {
            beginInteraction(state, input, .resizing);
        } else if (title_hovered) {
            beginInteraction(state, input, .moving);
        }
    }

    if (!config.input_enabled) {
        state.mode = .none;
        state.close_active = false;
    } else if (input.down) {
        const previous = state.rect;
        switch (state.mode) {
            .none => {},
            .moving => {
                state.rect.x = state.rect_origin.x + input.x - state.pointer_origin.x;
                state.rect.y = state.rect_origin.y + input.y - state.pointer_origin.y;
            },
            .resizing => {
                state.rect.width = state.rect_origin.width + input.x - state.pointer_origin.x;
                state.rect.height = state.rect_origin.height + input.y - state.pointer_origin.y;
            },
        }
        state.rect = clampRect(state.rect, config);
        result.rect_changed = !std.meta.eql(previous, state.rect);
    }

    if (input.released) {
        result.close_requested = state.close_active and close_hovered;
        state.close_active = false;
        state.mode = .none;
    }
    if (config.input_enabled and config.focused_id == closeId(config.id).id and
        input.activate_pressed)
    {
        result.close_requested = true;
    }
    result.interacting = state.mode != .none or state.close_active;

    if (config.semantic_registry) |registry| _ = registry.add(.{
        .element_id = panelId(config.id).id,
        .role = .group,
        .label = config.title,
    });
    if (config.semantic_registry) |registry| _ = registry.add(.{
        .element_id = closeId(config.id).id,
        .role = .button,
        .label = "关闭窗口",
        .focused = config.focused_id == closeId(config.id).id,
    });

    clay.UI()(.{
        .id = panelId(config.id),
        .layout = .{
            .sizing = .{ .w = .fixed(state.rect.width), .h = .fixed(state.rect.height) },
            .direction = .top_to_bottom,
        },
        .background_color = theme.controls.dialog,
        .corner_radius = .all(theme.controls.radius_large),
        .border = .{ .color = theme.controls.focus, .width = .outside(1) },
        .floating = .{
            .offset = .{ .x = state.rect.x, .y = state.rect.y },
            .z_index = config.z_index,
            .pointer_capture_mode = .capture,
            .attach_to = .to_root,
        },
    })({
        clay.UI()(.{
            .id = titleId(config.id),
            .layout = .{
                .sizing = .{ .w = .grow, .h = .fixed(config.title_height) },
                .padding = .axes(14, 10),
                .child_gap = 8,
                .child_alignment = .{ .x = .left, .y = .center },
            },
            .background_color = if (state.mode == .moving)
                theme.controls.surface_focused
            else if (title_hovered)
                theme.controls.surface_hover
            else
                theme.controls.surface,
            .corner_radius = .{ .top_left = theme.controls.radius_large, .top_right = theme.controls.radius_large },
        })({
            clay.UI()(.{ .layout = .{ .sizing = .{ .w = .grow, .h = .fit } } })({
                label.draw(config.title, .{ .font_size = 17, .color = theme.controls.text });
            });
            clay.UI()(.{
                .id = closeId(config.id),
                .layout = .{
                    .sizing = .{ .w = .fixed(28), .h = .fixed(28) },
                    .child_alignment = .center,
                },
                .background_color = if (state.close_active)
                    theme.controls.accent_pressed
                else if (close_hovered or config.focused_id == closeId(config.id).id)
                    theme.controls.surface_muted
                else
                    theme.controls.transparent,
                .corner_radius = .all(7),
            })({
                label.draw("×", .{ .font_size = 20, .color = theme.controls.text_secondary });
            });
        });
        clay.UI()(.{
            .layout = .{
                .sizing = .{ .w = .grow, .h = .grow },
                .padding = .all(14),
                .direction = .top_to_bottom,
            },
            .clip = .{ .horizontal = true, .vertical = true },
        })({
            if (config.draw_content) |draw_content| draw_content(config.content_context);
        });
        clay.UI()(.{
            .layout = .{
                .sizing = .{ .w = .grow, .h = .fixed(config.resize_handle_size) },
                .child_alignment = .{ .x = .right, .y = .bottom },
            },
        })({
            clay.UI()(.{
                .id = resizeId(config.id),
                .layout = .{
                    .sizing = .{
                        .w = .fixed(config.resize_handle_size),
                        .h = .fixed(config.resize_handle_size),
                    },
                    .padding = .all(5),
                    .child_alignment = .{ .x = .right, .y = .bottom },
                },
                .background_color = if (state.mode == .resizing or resize_hovered)
                    theme.controls.surface_hover
                else
                    theme.controls.transparent,
            })({
                clay.UI()(.{
                    .layout = .{ .sizing = .{ .w = .fixed(9), .h = .fixed(9) } },
                    .border = .{
                        .color = theme.controls.text_muted,
                        .width = .{ .right = 2, .bottom = 2 },
                    },
                })({});
            });
        });
    });
    return result;
}

fn beginInteraction(state: *State, input: interaction.Input, mode: State.Mode) void {
    state.mode = mode;
    state.pointer_origin = .{ .x = input.x, .y = input.y };
    state.rect_origin = state.rect;
}

fn pointerInsideElement(input: interaction.Input, id: clay.ElementId) bool {
    const data = clay.getElementData(id);
    return data.found and clay.pointerOver(id) and pointInside(input.x, input.y, data.bounding_box);
}

fn pointInside(x: f32, y: f32, bounds: clay.BoundingBox) bool {
    return x >= bounds.x and x <= bounds.x + bounds.width and
        y >= bounds.y and y <= bounds.y + bounds.height;
}

fn clampRect(rect: Rect, config: Config) Rect {
    var output = rect;
    output.width = @min(@max(output.width, config.min_width), @max(config.viewport_width, 1));
    output.height = @min(@max(output.height, config.min_height), @max(config.viewport_height, 1));
    output.x = @min(@max(output.x, 0), @max(config.viewport_width - output.width, 0));
    output.y = @min(@max(output.y, 0), @max(config.viewport_height - output.height, 0));
    return output;
}

test "floating window clamp keeps the complete window in its viewport" {
    const config: Config = .{
        .id = "Window",
        .title = "Window",
        .viewport_width = 800,
        .viewport_height = 600,
    };
    const rect = clampRect(.{ .x = 760, .y = -40, .width = 500, .height = 900 }, config);
    try std.testing.expectEqual(@as(f32, 300), rect.x);
    try std.testing.expectEqual(@as(f32, 0), rect.y);
    try std.testing.expectEqual(@as(f32, 500), rect.width);
    try std.testing.expectEqual(@as(f32, 600), rect.height);
}
