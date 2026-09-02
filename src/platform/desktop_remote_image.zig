const std = @import("std");
const platform = @import("platform.zig");

const Mutex = struct {
    raw: std.atomic.Mutex = .unlocked,

    fn lock(self: *Mutex) void {
        while (!self.raw.tryLock()) std.Thread.yield() catch {};
    }

    fn unlock(self: *Mutex) void {
        self.raw.unlock();
    }
};

/// Desktop HTTPS transport for runtime images. The worker owns all network
/// activity; `poll` is the only point where downloaded bytes reach app state.
pub const Loader = struct {
    mutex: Mutex = .{},
    thread: ?std.Thread = null,
    cancel_requested: std.atomic.Value(bool) = .init(false),
    status: Status = .idle,
    request_id: platform.RequestId = 0,
    chunk_bytes: usize = platform.remote_image_chunk_bytes,
    data: []u8 = &.{},
    emitted: usize = 0,
    failure: platform.RemoteImageError = .io,
    http_status: i32 = 0,

    const Status = enum {
        idle,
        downloading,
        ready,
        failed,
        cancelled,
    };

    pub const Event = union(enum) {
        chunk: platform.FileStreamChunk,
        completed: platform.FileStreamTerminal,
        failed: platform.RemoteImageFailure,
        cancelled: platform.FileStreamTerminal,
    };

    pub fn start(self: *Loader, request: platform.RemoteImageRequest) bool {
        self.mutex.lock();
        defer self.mutex.unlock();
        if (self.status != .idle or self.thread != null) return false;

        self.request_id = request.request_id;
        self.chunk_bytes = @max(@as(usize, request.chunk_bytes), 1);
        self.emitted = 0;
        self.failure = .io;
        self.http_status = 0;
        self.cancel_requested.store(false, .release);
        self.status = .downloading;
        self.thread = std.Thread.spawn(.{}, workerMain, .{ self, request }) catch {
            self.status = .idle;
            self.request_id = 0;
            return false;
        };
        return true;
    }

    pub fn cancel(self: *Loader, request_id: platform.RequestId) bool {
        self.mutex.lock();
        defer self.mutex.unlock();
        if (self.request_id != request_id or self.status == .idle) return false;
        self.cancel_requested.store(true, .release);
        if (self.status == .ready) {
            if (self.data.len > 0) std.heap.c_allocator.free(self.data);
            self.data = &.{};
            self.emitted = 0;
            self.status = .cancelled;
        }
        return true;
    }

    /// Returned chunk bytes remain valid until the next call to `poll`.
    pub fn poll(self: *Loader) ?Event {
        self.reapFinished();

        self.mutex.lock();
        defer self.mutex.unlock();
        return switch (self.status) {
            .idle, .downloading => null,
            .ready => if (self.emitted < self.data.len) blk: {
                const offset = self.emitted;
                const end = @min(self.data.len, offset + self.chunk_bytes);
                self.emitted = end;
                break :blk .{ .chunk = .{
                    .request_id = self.request_id,
                    .offset = offset,
                    .data = self.data[offset..end],
                } };
            } else blk: {
                const terminal: platform.FileStreamTerminal = .{
                    .request_id = self.request_id,
                    .total_bytes = self.data.len,
                };
                self.resetLocked();
                break :blk .{ .completed = terminal };
            },
            .failed => blk: {
                const terminal: platform.RemoteImageFailure = .{
                    .request_id = self.request_id,
                    .error_kind = self.failure,
                    .http_status = self.http_status,
                };
                self.resetLocked();
                break :blk .{ .failed = terminal };
            },
            .cancelled => blk: {
                const terminal: platform.FileStreamTerminal = .{
                    .request_id = self.request_id,
                    .total_bytes = self.data.len,
                };
                self.resetLocked();
                break :blk .{ .cancelled = terminal };
            },
        };
    }

    pub fn deinit(self: *Loader) void {
        self.cancel_requested.store(true, .release);
        const thread = self.takeThread();
        if (thread) |running| running.join();
        self.mutex.lock();
        defer self.mutex.unlock();
        self.resetLocked();
    }

    fn workerMain(self: *Loader, request: platform.RemoteImageRequest) void {
        const outcome = download(
            std.heap.c_allocator,
            request.url(),
            request.max_bytes,
            &self.cancel_requested,
        );

        self.mutex.lock();
        defer self.mutex.unlock();
        switch (outcome) {
            .success => |bytes| {
                if (self.cancel_requested.load(.acquire)) {
                    std.heap.c_allocator.free(bytes);
                    self.status = .cancelled;
                } else {
                    self.data = bytes;
                    self.status = .ready;
                }
            },
            .failure => |download_failure| {
                self.failure = download_failure.kind;
                self.http_status = download_failure.http_status;
                self.status = if (download_failure.kind == .unsupported and
                    self.cancel_requested.load(.acquire)) .cancelled else .failed;
            },
        }
    }

    fn reapFinished(self: *Loader) void {
        self.mutex.lock();
        if (self.status == .downloading or self.thread == null) {
            self.mutex.unlock();
            return;
        }
        const thread = self.thread;
        self.thread = null;
        self.mutex.unlock();
        if (thread) |finished| finished.join();
    }

    fn takeThread(self: *Loader) ?std.Thread {
        self.mutex.lock();
        defer self.mutex.unlock();
        const thread = self.thread;
        self.thread = null;
        return thread;
    }

    fn resetLocked(self: *Loader) void {
        if (self.data.len > 0) std.heap.c_allocator.free(self.data);
        self.data = &.{};
        self.status = .idle;
        self.request_id = 0;
        self.emitted = 0;
        self.http_status = 0;
        self.cancel_requested.store(false, .release);
    }
};

const DownloadOutcome = union(enum) {
    success: []u8,
    failure: struct {
        kind: platform.RemoteImageError,
        http_status: i32 = 0,
    },
};

fn download(
    allocator: std.mem.Allocator,
    url: []const u8,
    max_bytes: u32,
    cancelled: *const std.atomic.Value(bool),
) DownloadOutcome {
    const uri = std.Uri.parse(url) catch return failure(.invalid_url);
    if (!std.ascii.eqlIgnoreCase(uri.scheme, "https")) return failure(.invalid_url);
    if (cancelled.load(.acquire)) return failure(.unsupported);

    var threaded: std.Io.Threaded = .init(allocator, .{});
    defer threaded.deinit();
    var client: std.http.Client = .{
        .allocator = allocator,
        .io = threaded.io(),
    };
    defer client.deinit();

    var request = client.request(.GET, uri, .{
        .redirect_behavior = std.http.Client.Request.RedirectBehavior.init(5),
        .headers = .{
            .user_agent = .{ .override = "zapp/0.1" },
            .accept_encoding = .omit,
        },
        .extra_headers = &.{.{
            .name = "Accept",
            .value = "image/png, image/jpeg",
        }},
    }) catch return failure(.io);
    defer request.deinit();
    request.sendBodiless() catch return failure(.io);

    var redirect_buffer: [8 * 1024]u8 = undefined;
    var response = request.receiveHead(&redirect_buffer) catch |err| return switch (err) {
        error.TooManyHttpRedirects, error.HttpRedirectLocationMissing => failure(.http_status),
        else => failure(.io),
    };
    if (!std.ascii.eqlIgnoreCase(request.uri.scheme, "https")) return failure(.invalid_url);
    if (response.head.status.class() != .success) return .{ .failure = .{
        .kind = .http_status,
        .http_status = @intFromEnum(response.head.status),
    } };
    if (!isSupportedContentType(response.head.content_type)) return failure(.unsupported_content_type);
    if (response.head.content_length) |length| {
        if (length > max_bytes) return failure(.too_large);
    }
    if (cancelled.load(.acquire)) return failure(.unsupported);

    var transfer_buffer: [platform.remote_image_chunk_bytes]u8 = undefined;
    const reader = response.reader(&transfer_buffer);
    const bytes = reader.allocRemaining(allocator, .limited(max_bytes)) catch |err| return switch (err) {
        error.StreamTooLong => failure(.too_large),
        else => failure(.io),
    };
    if (cancelled.load(.acquire)) {
        allocator.free(bytes);
        return failure(.unsupported);
    }
    return .{ .success = bytes };
}

fn failure(kind: platform.RemoteImageError) DownloadOutcome {
    return .{ .failure = .{ .kind = kind } };
}

fn isSupportedContentType(content_type: ?[]const u8) bool {
    const value = content_type orelse return false;
    const media_type_with_params = if (std.mem.cutScalar(u8, value, ';')) |parts| parts[0] else value;
    const media_type = std.mem.trim(u8, media_type_with_params, " \t");
    return std.ascii.eqlIgnoreCase(media_type, "image/png") or
        std.ascii.eqlIgnoreCase(media_type, "image/jpeg");
}

test "desktop remote image content type validation" {
    try std.testing.expect(isSupportedContentType("image/png"));
    try std.testing.expect(isSupportedContentType("IMAGE/JPEG; charset=binary"));
    try std.testing.expect(!isSupportedContentType("image/webp"));
    try std.testing.expect(!isSupportedContentType(null));
}

test "idle desktop remote image loader has no events" {
    var loader: Loader = .{};
    defer loader.deinit();
    try std.testing.expect(loader.poll() == null);
    try std.testing.expect(!loader.cancel(99));
}
