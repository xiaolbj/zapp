pub const Action = @import("action.zig").Action;
pub const Model = @import("model.zig").Model;
const reducer = @import("reducer.zig");

pub const App = struct {
    model: Model = .{},

    pub fn dispatch(self: *App, action: Action) void {
        reducer.update(&self.model, action);
    }
};

test {
    _ = @import("reducer.zig");
}
