pub const RequestId = u64;

pub const Permission = enum {
    camera,
    microphone,
    notifications,
    media,
};

/// Logical navigation produced by a gamepad, TV remote, keyboard adapter, or
/// assistive input device. Native adapters translate platform-specific codes
/// before they enter the application state.
pub const NavigationCommand = enum {
    next,
    previous,
    activate,
    decrement,
    increment,
    back,
};

pub const PlatformEvent = union(enum) {
    permission_result: struct {
        request_id: RequestId,
        permission: Permission,
        granted: bool,
    },
    file_selected: struct {
        request_id: RequestId,
        path: []const u8,
    },
    file_selection_cancelled: RequestId,
    ime_composition_changed: []const u8,
    ime_composition_committed: []const u8,
    ime_composition_cancelled,
    navigation_requested: NavigationCommand,
};

/// Platform implementations enqueue results and the app consumes them on its
/// update thread. No platform call is allowed to synchronously block rendering.
pub const EventSink = struct {
    context: ?*anyopaque,
    push_fn: *const fn (?*anyopaque, PlatformEvent) void,

    pub fn push(self: EventSink, event: PlatformEvent) void {
        self.push_fn(self.context, event);
    }
};
