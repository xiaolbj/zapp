const clay = @import("zclay");
const interaction = @import("interaction.zig");
const label = @import("label.zig");
const theme = @import("../theme.zig");

pub const Config = struct {
    id: []const u8,
    text: []const u8,
    checked: bool,
    width: f32 = 260,
    disabled: bool = false,
    focused: bool = false,
};

pub fn draw(state: *interaction.State, input: interaction.Input, config: Config) bool {
    const id = clay.ElementId.ID(config.id);
    const result = interaction.update(state, id.id, clay.pointerOver(id), input, config.disabled);
    const track_color: clay.Color = if (config.disabled)
        theme.controls.surface_disabled
    else if (config.checked)
        if (result.active) theme.controls.accent_pressed else theme.controls.accent
    else if (result.hovered or config.focused)
        theme.controls.switch_inactive_hover
    else
        theme.controls.switch_inactive;

    clay.UI()(.{
        .id = id,
        .layout = .{
            .sizing = .{ .w = .fixed(config.width), .h = .fixed(40) },
            .child_gap = theme.controls.gap_medium,
            .child_alignment = .{ .y = .center },
        },
    })({
        clay.UI()(.{
            .layout = .{
                .sizing = .{ .w = .fixed(52), .h = .fixed(30) },
                .padding = .all(4),
                .child_alignment = .{
                    .x = if (config.checked) .right else .left,
                    .y = .center,
                },
            },
            .background_color = track_color,
            .corner_radius = .all(30 * 0.5),
        })({
            clay.UI()(.{
                .layout = .{ .sizing = .{ .w = .fixed(22), .h = .fixed(22) } },
                .background_color = if (config.disabled) theme.controls.thumb_disabled else theme.controls.thumb,
                .corner_radius = .all(22 * 0.5),
            })({});
        });
        label.draw(config.text, .{
            .color = if (config.disabled) theme.controls.text_disabled else theme.controls.text_secondary,
        });
    });

    return result.clicked or (config.focused and input.activate_pressed and !config.disabled);
}
