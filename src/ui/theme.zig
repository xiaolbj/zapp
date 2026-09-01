pub const Color = struct {
    r: f32,
    g: f32,
    b: f32,
    a: f32 = 1,
};

pub const Theme = struct {
    background: Color,
    surface: Color,
    primary: Color,
    text: Color,
};

pub const dark: Theme = .{
    .background = .{ .r = 0.035, .g = 0.047, .b = 0.075 },
    .surface = .{ .r = 0.075, .g = 0.094, .b = 0.135 },
    .primary = .{ .r = 0.255, .g = 0.553, .b = 0.953 },
    .text = .{ .r = 0.92, .g = 0.94, .b = 0.97 },
};

/// Shared design tokens used by every reusable widget.
pub const controls = struct {
    pub const accent: clay.Color = .{ 42, 111, 204, 255 };
    pub const accent_hover: clay.Color = .{ 55, 132, 229, 255 };
    pub const accent_pressed: clay.Color = .{ 30, 85, 164, 255 };
    pub const focus: clay.Color = .{ 116, 184, 255, 255 };
    pub const selection: clay.Color = .{ 43, 111, 184, 255 };
    pub const surface: clay.Color = .{ 30, 41, 58, 255 };
    pub const surface_hover: clay.Color = .{ 37, 54, 79, 255 };
    pub const surface_focused: clay.Color = .{ 39, 62, 91, 255 };
    pub const surface_muted: clay.Color = .{ 49, 61, 81, 255 };
    pub const surface_disabled: clay.Color = .{ 64, 75, 94, 255 };
    pub const surface_disabled_soft: clay.Color = .{ 68, 78, 94, 255 };
    pub const control_inactive: clay.Color = .{ 53, 66, 87, 255 };
    pub const control_inactive_hover: clay.Color = .{ 74, 91, 117, 255 };
    pub const switch_inactive: clay.Color = .{ 55, 67, 85, 255 };
    pub const switch_inactive_hover: clay.Color = .{ 79, 94, 116, 255 };
    pub const navigation_active: clay.Color = .{ 42, 91, 153, 255 };
    pub const transparent: clay.Color = .{ 0, 0, 0, 0 };
    pub const input_disabled: clay.Color = .{ 43, 51, 64, 255 };
    pub const input_hover: clay.Color = .{ 37, 49, 68, 255 };
    pub const track_disabled: clay.Color = .{ 69, 78, 93, 255 };
    pub const card: clay.Color = .{ 31, 45, 70, 255 };
    pub const scroll_surface: clay.Color = .{ 22, 34, 53, 255 };
    pub const dialog: clay.Color = .{ 27, 40, 62, 255 };
    pub const dialog_button: clay.Color = .{ 57, 70, 91, 255 };
    pub const dialog_button_hover: clay.Color = .{ 72, 88, 114, 255 };
    pub const dialog_button_pressed: clay.Color = .{ 45, 56, 74, 255 };
    pub const overlay: clay.Color = .{ 2, 6, 14, 190 };
    pub const success: clay.Color = .{ 28, 95, 73, 245 };
    pub const text: clay.Color = .{ 232, 239, 249, 255 };
    pub const text_muted: clay.Color = .{ 166, 187, 218, 255 };
    pub const text_disabled: clay.Color = .{ 132, 143, 160, 255 };
    pub const text_placeholder: clay.Color = .{ 118, 135, 158, 255 };
    pub const text_secondary: clay.Color = .{ 222, 231, 244, 255 };
    pub const text_dialog: clay.Color = .{ 174, 191, 216, 255 };
    pub const text_navigation: clay.Color = .{ 163, 183, 211, 255 };
    pub const text_composition: clay.Color = .{ 183, 220, 255, 255 };
    pub const composition: clay.Color = .{ 60, 82, 116, 255 };
    pub const on_accent: clay.Color = .{ 248, 251, 255, 255 };
    pub const thumb: clay.Color = .{ 247, 250, 255, 255 };
    pub const thumb_disabled: clay.Color = .{ 156, 164, 176, 255 };
    pub const thumb_focused: clay.Color = .{ 174, 215, 255, 255 };
    pub const toast_text: clay.Color = .{ 240, 255, 249, 255 };
    pub const divider: clay.Color = .{ 58, 76, 104, 255 };

    pub const radius_small: f32 = 6;
    pub const radius_cursor: f32 = 1;
    pub const radius_composition: f32 = 2;
    pub const radius_selection: f32 = 3;
    pub const radius_track: f32 = 4;
    pub const radius_medium: f32 = 10;
    pub const radius_large: f32 = 14;
    pub const gap_small: u16 = 8;
    pub const gap_medium: u16 = 12;
    pub const control_height: f32 = 48;
};

test "control tokens preserve readable alpha" {
    const std = @import("std");
    try std.testing.expect(controls.accent[3] == 255);
    try std.testing.expect(controls.text[3] == 255);
    try std.testing.expect(controls.overlay[3] > 0);
}
const clay = @import("zclay");
