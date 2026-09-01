pub const State = struct {
    const max_ordered_items = 48;

    focused_id: ?u32 = null,
    previous_focus_id: ?u32 = null,
    modal_id: ?u32 = null,
    ordered_ids: [max_ordered_items]u32 = @splat(0),
    ordered_count: usize = 0,

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

    pub fn setOrder(self: *State, ids: []const u32) void {
        self.ordered_count = @min(ids.len, self.ordered_ids.len);
        @memcpy(self.ordered_ids[0..self.ordered_count], ids[0..self.ordered_count]);
    }

    pub fn move(self: *State, direction: i8) ?u32 {
        if (self.ordered_count == 0) return null;
        var current_index: ?usize = null;
        if (self.focused_id) |focused| {
            for (self.ordered_ids[0..self.ordered_count], 0..) |id, index| {
                if (id == focused) {
                    current_index = index;
                    break;
                }
            }
        }
        const next_index = if (current_index) |index|
            if (direction < 0)
                if (index == 0) self.ordered_count - 1 else index - 1
            else
                (index + 1) % self.ordered_count
        else if (direction < 0)
            self.ordered_count - 1
        else
            0;
        self.focused_id = self.ordered_ids[next_index];
        return self.focused_id;
    }

    pub fn isFocused(self: *const State, id: u32) bool {
        return self.focused_id == id;
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

test "ordered focus wraps in both directions" {
    const std = @import("std");
    var state: State = .{};
    state.setOrder(&.{ 3, 5, 8 });

    try std.testing.expectEqual(@as(?u32, 3), state.move(1));
    try std.testing.expectEqual(@as(?u32, 5), state.move(1));
    try std.testing.expectEqual(@as(?u32, 3), state.move(-1));
    try std.testing.expectEqual(@as(?u32, 8), state.move(-1));
}
