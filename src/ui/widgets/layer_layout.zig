const std = @import("std");
const clay = @import("zclay");
const interaction = @import("interaction.zig");
const label = @import("label.zig");
const semantics = @import("../semantics.zig");
const theme = @import("../theme.zig");

pub const max_layers = 4;
pub const DrawLayerFn = *const fn (context: ?*anyopaque, layer_id: u32) void;

pub const Layer = struct {
    id: u32,
    title: []const u8,
};

pub const State = struct {
    order: [max_layers]u32 = .{ 0, 1, 2, 3 },
    count: usize = 0,
    active_layer_id: ?u32 = null,
    splitter_active: bool = false,
    split_ratio: f32 = 0.5,
};

pub const Config = struct {
    id: []const u8,
    layers: []const Layer,
    width: f32,
    height: f32 = 220,
    min_panel_width: f32 = 120,
    splitter_width: f32 = 10,
    input_enabled: bool = true,
    draw_layer: ?DrawLayerFn = null,
    layer_context: ?*anyopaque = null,
    semantic_registry: ?*semantics.Registry = null,
};

pub const Result = struct {
    order_changed: bool = false,
    split_changed: bool = false,
    interacting: bool = false,
};

pub fn containerId(id: []const u8) clay.ElementId {
    return clay.ElementId.ID(id);
}

pub fn panelId(id: []const u8, layer_id: u32) clay.ElementId {
    return clay.ElementId.IDI(id, 100 +% layer_id *% 2);
}

pub fn headerId(id: []const u8, layer_id: u32) clay.ElementId {
    return clay.ElementId.IDI(id, 101 +% layer_id *% 2);
}

pub fn splitterId(id: []const u8) clay.ElementId {
    return clay.ElementId.IDI(id, 99);
}

pub fn claimsPointer(state: *const State, input: interaction.Input, config: Config) bool {
    if (input.down and (state.active_layer_id != null or state.splitter_active)) return true;
    if (!input.pressed) return false;
    if (pointerInsideElement(input, splitterId(config.id))) return true;
    for (config.layers) |layer| {
        if (pointerInsideElement(input, headerId(config.id, layer.id))) return true;
    }
    return false;
}

pub fn draw(state: *State, input: interaction.Input, config: Config) Result {
    ensureOrder(state, config.layers);
    var result: Result = .{};
    const count = @min(config.layers.len, max_layers);

    if (!config.input_enabled) {
        state.active_layer_id = null;
        state.splitter_active = false;
    } else if (input.pressed) {
        if (count == 2 and pointerInsideElement(input, splitterId(config.id))) {
            state.splitter_active = true;
        } else {
            for (config.layers[0..count]) |layer| {
                if (pointerInsideElement(input, headerId(config.id, layer.id))) {
                    state.active_layer_id = layer.id;
                    break;
                }
            }
        }
    }

    if (state.splitter_active and input.down) {
        const container = clay.getElementData(containerId(config.id));
        if (container.found) {
            const available = @max(container.bounding_box.width - config.splitter_width, 1);
            const minimum_ratio = @min(config.min_panel_width / available, 0.45);
            const next = @min(@max(
                (input.x - container.bounding_box.x - config.splitter_width * 0.5) / available,
                minimum_ratio,
            ), 1 - minimum_ratio);
            result.split_changed = @abs(next - state.split_ratio) > 0.0001;
            state.split_ratio = next;
        }
    } else if (state.active_layer_id) |active_id| {
        if (input.down) {
            for (config.layers[0..count]) |target| {
                if (target.id == active_id) continue;
                if (pointerInsideElement(input, panelId(config.id, target.id))) {
                    result.order_changed = swapLayers(state, active_id, target.id);
                    break;
                }
            }
        }
    }

    if (input.released) {
        state.active_layer_id = null;
        state.splitter_active = false;
    }
    result.interacting = state.active_layer_id != null or state.splitter_active;

    if (config.semantic_registry) |registry| _ = registry.add(.{
        .element_id = containerId(config.id).id,
        .role = .group,
        .label = "Layer layout",
    });

    clay.UI()(.{
        .id = containerId(config.id),
        .layout = .{
            .sizing = .{ .w = .fixed(config.width), .h = .fixed(config.height) },
            .direction = .left_to_right,
            .child_alignment = .{ .y = .top },
        },
        .background_color = theme.controls.scroll_surface,
        .corner_radius = .all(theme.controls.radius_medium),
        .border = .{ .color = theme.controls.divider, .width = .outside(1) },
    })({
        for (state.order[0..count], 0..) |layer_id, slot| {
            const layer = findLayer(config.layers, layer_id) orelse continue;
            const panel_width = widthForSlot(state, config, count, slot);
            drawPanel(state, config, layer, panel_width);
            if (count == 2 and slot == 0) {
                clay.UI()(.{
                    .id = splitterId(config.id),
                    .layout = .{
                        .sizing = .{ .w = .fixed(config.splitter_width), .h = .grow },
                        .child_alignment = .center,
                    },
                    .background_color = if (state.splitter_active)
                        theme.controls.focus
                    else if (clay.pointerOver(splitterId(config.id)))
                        theme.controls.accent_hover
                    else
                        theme.controls.divider,
                })({
                    clay.UI()(.{
                        .layout = .{ .sizing = .{ .w = .fixed(2), .h = .fixed(48) } },
                        .background_color = theme.controls.text_muted,
                        .corner_radius = .all(1),
                    })({});
                });
            }
        }
    });
    return result;
}

fn drawPanel(state: *const State, config: Config, layer: Layer, width: f32) void {
    const active = state.active_layer_id == layer.id;
    clay.UI()(.{
        .id = panelId(config.id, layer.id),
        .layout = .{
            .sizing = .{ .w = .fixed(width), .h = .grow },
            .direction = .top_to_bottom,
        },
        .background_color = theme.controls.surface,
    })({
        clay.UI()(.{
            .id = headerId(config.id, layer.id),
            .layout = .{
                .sizing = .{ .w = .grow, .h = .fixed(40) },
                .padding = .axes(12, 9),
                .child_alignment = .{ .y = .center },
            },
            .background_color = if (active)
                theme.controls.surface_focused
            else if (clay.pointerOver(headerId(config.id, layer.id)))
                theme.controls.surface_hover
            else
                theme.controls.card,
            .border = .{ .color = theme.controls.divider, .width = .{ .bottom = 1 } },
        })({
            label.draw(layer.title, .{ .font_size = 15, .color = theme.controls.text });
        });
        clay.UI()(.{
            .layout = .{
                .sizing = .{ .w = .grow, .h = .grow },
                .padding = .all(12),
                .direction = .top_to_bottom,
                .child_gap = 8,
            },
        })({
            if (config.draw_layer) |draw_layer| draw_layer(config.layer_context, layer.id);
        });
    });
}

fn widthForSlot(state: *const State, config: Config, count: usize, slot: usize) f32 {
    if (count == 0) return 0;
    if (count == 2) {
        const available = @max(config.width - config.splitter_width, 0);
        if (slot == 0) return available * state.split_ratio;
        return available * (1 - state.split_ratio);
    }
    return config.width / @as(f32, @floatFromInt(count));
}

fn ensureOrder(state: *State, layers: []const Layer) void {
    const count = @min(layers.len, max_layers);
    var valid = state.count == count;
    if (valid) {
        for (layers[0..count]) |layer| {
            var found = false;
            for (state.order[0..count]) |ordered_id| {
                if (ordered_id == layer.id) {
                    found = true;
                    break;
                }
            }
            if (!found) {
                valid = false;
                break;
            }
        }
    }
    if (valid) return;
    state.count = count;
    for (0..count) |index| state.order[index] = layers[index].id;
    state.active_layer_id = null;
    state.splitter_active = false;
}

fn swapLayers(state: *State, active_id: u32, target_id: u32) bool {
    var active_slot: ?usize = null;
    var target_slot: ?usize = null;
    for (state.order[0..state.count], 0..) |layer_id, slot| {
        if (layer_id == active_id) active_slot = slot;
        if (layer_id == target_id) target_slot = slot;
    }
    const from = active_slot orelse return false;
    const to = target_slot orelse return false;
    if (from == to) return false;
    std.mem.swap(u32, &state.order[from], &state.order[to]);
    return true;
}

fn findLayer(layers: []const Layer, id: u32) ?Layer {
    for (layers) |layer| {
        if (layer.id == id) return layer;
    }
    return null;
}

fn pointerInsideElement(input: interaction.Input, id: clay.ElementId) bool {
    const data = clay.getElementData(id);
    return data.found and clay.pointerOver(id) and input.x >= data.bounding_box.x and
        input.x <= data.bounding_box.x + data.bounding_box.width and
        input.y >= data.bounding_box.y and
        input.y <= data.bounding_box.y + data.bounding_box.height;
}

test "layer reordering swaps the active and target slots" {
    var state: State = .{ .count = 3 };
    try std.testing.expect(swapLayers(&state, 2, 0));
    try std.testing.expectEqualSlices(u32, &.{ 2, 1, 0 }, state.order[0..3]);
    try std.testing.expect(swapLayers(&state, 2, 1));
    try std.testing.expectEqualSlices(u32, &.{ 1, 2, 0 }, state.order[0..3]);
}

test "two-panel widths preserve available space" {
    const config: Config = .{
        .id = "Layers",
        .layers = &.{},
        .width = 600,
        .splitter_width = 10,
    };
    const state: State = .{ .split_ratio = 0.3 };
    try std.testing.expectApproxEqAbs(@as(f32, 177), widthForSlot(&state, config, 2, 0), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 413), widthForSlot(&state, config, 2, 1), 0.001);
}
