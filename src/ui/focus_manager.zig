pub const State = struct {
    focused_id: ?u32 = null,
    previous_focus_id: ?u32 = null,
    modal_id: ?u32 = null,

    pub fn focus(self: *State, id: u32) void {
        self.focused_id = id;
    }

    pub fn openModal(self: *State, modal_id: u32, initial_focus_id: u32) void {
        if (self.modal_id == modal_id) return;
        self.previous_focus_id = self.focused_id;
        self.modal_id = modal_id;
        self.focused_id = initial_focus_id;
    }

    pub fn closeModal(self: *State, modal_id: u32) void {
        if (self.modal_id != modal_id) return;
        self.modal_id = null;
        self.focused_id = self.previous_focus_id;
        self.previous_focus_id = null;
    }

    pub fn modalOpen(self: *const State) bool {
        return self.modal_id != null;
    }
};

test "modal focus is initialized and restored" {
    const std = @import("std");
    var state: State = .{};

    state.focus(5);
    state.openModal(10, 11);
    try std.testing.expectEqual(@as(?u32, 10), state.modal_id);
    try std.testing.expectEqual(@as(?u32, 11), state.focused_id);
    try std.testing.expectEqual(@as(?u32, 5), state.previous_focus_id);

    state.openModal(10, 12);
    try std.testing.expectEqual(@as(?u32, 11), state.focused_id);
    try std.testing.expectEqual(@as(?u32, 5), state.previous_focus_id);

    state.closeModal(10);
    try std.testing.expectEqual(@as(?u32, null), state.modal_id);
    try std.testing.expectEqual(@as(?u32, 5), state.focused_id);
}

test "unrelated modal cannot steal focus restoration" {
    const std = @import("std");
    var state: State = .{};
    state.openModal(10, 11);
    state.closeModal(99);

    try std.testing.expect(state.modalOpen());
    try std.testing.expectEqual(@as(?u32, 11), state.focused_id);
}
