pub const Action = @import("action.zig").Action;
pub const Model = @import("model.zig").Model;
const reducer = @import("reducer.zig");
const PlatformEvent = @import("../platform/platform.zig").PlatformEvent;

pub const App = struct {
    model: Model = .{},

    pub fn dispatch(self: *App, action: Action) void {
        reducer.update(&self.model, action);
    }

    /// Platform event payloads are consumed synchronously on the update thread.
    pub fn dispatchPlatformEvent(self: *App, event: PlatformEvent) void {
        switch (event) {
            .ime_composition_changed => |text| self.dispatch(.{ .text_composition_changed = text }),
            .ime_composition_committed => |text| self.dispatch(.{ .text_composition_committed = text }),
            .ime_composition_cancelled => self.dispatch(.text_composition_cancelled),
            .navigation_requested => |command| switch (command) {
                .next => self.dispatch(.focus_next_requested),
                .previous => self.dispatch(.focus_previous_requested),
                .activate => self.dispatch(.focused_control_activate_requested),
                .decrement => self.dispatch(.focused_control_left_requested),
                .increment => self.dispatch(.focused_control_right_requested),
                .back => self.dispatch(.back_requested),
            },
            else => {},
        }
    }
};

test "IME platform events enter the reducer synchronously" {
    const std = @import("std");
    var app: App = .{};
    app.dispatchPlatformEvent(.{ .ime_composition_changed = "ni" });
    try std.testing.expectEqualStrings("ni", app.model.textComposition());
    app.dispatchPlatformEvent(.{ .ime_composition_committed = "你" });
    try std.testing.expectEqualStrings("你", app.model.text());
}

test "platform navigation commands share frame-latched focus actions" {
    const std = @import("std");
    var app: App = .{};
    app.dispatchPlatformEvent(.{ .navigation_requested = .next });
    app.dispatchPlatformEvent(.{ .navigation_requested = .activate });
    app.dispatchPlatformEvent(.{ .navigation_requested = .increment });
    app.dispatchPlatformEvent(.{ .navigation_requested = .back });

    try std.testing.expect(app.model.focus_next_requested);
    try std.testing.expect(app.model.focused_control_activate_requested);
    try std.testing.expect(app.model.focused_control_right_requested);
    try std.testing.expect(app.model.back_requested);

    app.dispatch(.input_consumed);
    try std.testing.expect(!app.model.focus_next_requested);
    try std.testing.expect(!app.model.focused_control_activate_requested);
    try std.testing.expect(!app.model.focused_control_right_requested);
    try std.testing.expect(!app.model.back_requested);
}

test {
    _ = @import("reducer.zig");
}
