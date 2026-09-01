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

test {
    _ = @import("reducer.zig");
}
