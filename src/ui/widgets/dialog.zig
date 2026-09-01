const clay = @import("zclay");
const button = @import("button.zig");
const interaction = @import("interaction.zig");
const label = @import("label.zig");
const semantics = @import("../semantics.zig");
const theme = @import("../theme.zig");

pub const Config = struct {
    overlay_id: []const u8,
    panel_id: []const u8,
    cancel_id: []const u8,
    confirm_id: []const u8,
    title: []const u8,
    message: []const u8,
    viewport_width: f32,
    viewport_height: f32,
    width: f32 = 420,
    focused_id: ?u32 = null,
    semantic_registry: ?*semantics.Registry = null,
};

pub const Result = struct {
    close_requested: bool = false,
    confirmed: bool = false,
};

pub fn draw(state: *interaction.State, input: interaction.Input, config: Config) Result {
    const overlay_id = clay.ElementId.ID(config.overlay_id);
    const panel_id = clay.ElementId.ID(config.panel_id);
    if (config.semantic_registry) |registry| _ = registry.add(.{
        .element_id = panel_id.id,
        .role = .dialog,
        .label = config.title,
        .modal = true,
    });
    const overlay_hovered = clay.pointerOver(overlay_id) and !clay.pointerOver(panel_id);
    const overlay_result = interaction.update(state, overlay_id.id, overlay_hovered, input, false);
    var result: Result = .{ .close_requested = overlay_result.clicked };

    clay.UI()(.{
        .id = overlay_id,
        .layout = .{
            .sizing = .{
                .w = .fixed(config.viewport_width),
                .h = .fixed(config.viewport_height),
            },
            .child_alignment = .center,
        },
        .background_color = theme.controls.overlay,
        .floating = .{
            .z_index = 100,
            .pointer_capture_mode = .capture,
            .attach_to = .to_root,
        },
    })({
        clay.UI()(.{
            .id = panel_id,
            .layout = .{
                .sizing = .{ .w = .fixed(config.width), .h = .fit },
                .padding = .all(24),
                .child_gap = theme.controls.gap_medium,
                .direction = .top_to_bottom,
            },
            .background_color = theme.controls.dialog,
            .corner_radius = .all(theme.controls.radius_large),
        })({
            label.draw(config.title, .{ .font_size = 22, .color = theme.controls.text });
            label.draw(config.message, .{
                .font_size = 16,
                .color = theme.controls.text_dialog,
                .wrap_mode = .words,
            });
            clay.UI()(.{ .layout = .{
                .sizing = .{ .w = .grow, .h = .fit },
                .child_gap = theme.controls.gap_medium,
                .child_alignment = .{ .x = .right },
            } })({
                if (button.draw(state, input, .{
                    .id = config.cancel_id,
                    .text = "取消",
                    .width = 112,
                    .normal_color = theme.controls.dialog_button,
                    .hover_color = theme.controls.dialog_button_hover,
                    .pressed_color = theme.controls.dialog_button_pressed,
                    .focused = config.focused_id == clay.ElementId.ID(config.cancel_id).id,
                    .semantic_modal = true,
                    .semantic_registry = config.semantic_registry,
                })) result.close_requested = true;
                if (button.draw(state, input, .{
                    .id = config.confirm_id,
                    .text = "确认",
                    .width = 112,
                    .focused = config.focused_id == clay.ElementId.ID(config.confirm_id).id,
                    .semantic_modal = true,
                    .semantic_registry = config.semantic_registry,
                })) {
                    result.confirmed = true;
                    result.close_requested = true;
                }
            });
        });
    });

    return result;
}
