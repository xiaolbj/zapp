const std = @import("std");

pub const max_samples = 120;
pub const report_interval_ms: f32 = 500;
pub const slow_frame_threshold_ms: f32 = 1000.0 / 60.0;

pub const Sample = struct {
    frame_interval_ms: f32 = 0,
    ui_cpu_ms: f32 = 0,
    render_cpu_ms: f32 = 0,
    total_cpu_ms: f32 = 0,
    command_count: u32 = 0,
    semantic_node_count: u32 = 0,
};

pub const Snapshot = struct {
    sample_count: u16 = 0,
    fps: f32 = 0,
    average_frame_ms: f32 = 0,
    p95_frame_ms: f32 = 0,
    slowest_frame_ms: f32 = 0,
    slow_frame_percent: f32 = 0,
    average_ui_cpu_ms: f32 = 0,
    average_render_cpu_ms: f32 = 0,
    average_total_cpu_ms: f32 = 0,
    average_command_count: u32 = 0,
    peak_command_count: u32 = 0,
    average_semantic_node_count: u32 = 0,
};

/// Fixed-memory rolling collector. `record` returns a new snapshot at most
/// twice per second so consumers do not need to format telemetry every frame.
pub const Collector = struct {
    samples: [max_samples]Sample = undefined,
    count: usize = 0,
    next_index: usize = 0,
    elapsed_since_report_ms: f32 = 0,

    pub fn reset(self: *Collector) void {
        self.* = .{};
    }

    pub fn record(self: *Collector, raw_sample: Sample) ?Snapshot {
        const sample = sanitize(raw_sample);
        self.samples[self.next_index] = sample;
        self.next_index = (self.next_index + 1) % max_samples;
        self.count = @min(self.count + 1, max_samples);
        self.elapsed_since_report_ms += sample.frame_interval_ms;
        if (self.elapsed_since_report_ms < report_interval_ms) return null;
        self.elapsed_since_report_ms = @mod(self.elapsed_since_report_ms, report_interval_ms);
        return self.snapshot();
    }

    pub fn snapshot(self: *const Collector) Snapshot {
        if (self.count == 0) return .{};

        var frame_times: [max_samples]f32 = undefined;
        var frame_total: f64 = 0;
        var ui_total: f64 = 0;
        var render_total: f64 = 0;
        var cpu_total: f64 = 0;
        var command_total: u64 = 0;
        var semantic_total: u64 = 0;
        var peak_commands: u32 = 0;
        var slow_frames: usize = 0;

        for (self.samples[0..self.count], 0..) |sample, index| {
            frame_times[index] = sample.frame_interval_ms;
            frame_total += sample.frame_interval_ms;
            ui_total += sample.ui_cpu_ms;
            render_total += sample.render_cpu_ms;
            cpu_total += sample.total_cpu_ms;
            command_total += sample.command_count;
            semantic_total += sample.semantic_node_count;
            peak_commands = @max(peak_commands, sample.command_count);
            if (sample.frame_interval_ms > slow_frame_threshold_ms) slow_frames += 1;
        }
        insertionSort(frame_times[0..self.count]);

        const count_f64: f64 = @floatFromInt(self.count);
        const average_frame_ms: f32 = @floatCast(frame_total / count_f64);
        const percentile_index = @min((self.count * 95 + 99) / 100 - 1, self.count - 1);
        return .{
            .sample_count = @intCast(self.count),
            .fps = if (average_frame_ms > 0) 1000.0 / average_frame_ms else 0,
            .average_frame_ms = average_frame_ms,
            .p95_frame_ms = frame_times[percentile_index],
            .slowest_frame_ms = frame_times[self.count - 1],
            .slow_frame_percent = @floatCast(@as(f64, @floatFromInt(slow_frames)) * 100.0 / count_f64),
            .average_ui_cpu_ms = @floatCast(ui_total / count_f64),
            .average_render_cpu_ms = @floatCast(render_total / count_f64),
            .average_total_cpu_ms = @floatCast(cpu_total / count_f64),
            .average_command_count = @intFromFloat(@round(@as(f64, @floatFromInt(command_total)) / count_f64)),
            .peak_command_count = peak_commands,
            .average_semantic_node_count = @intFromFloat(@round(@as(f64, @floatFromInt(semantic_total)) / count_f64)),
        };
    }
};

fn sanitize(sample: Sample) Sample {
    var result = sample;
    result.frame_interval_ms = sanitizeDuration(result.frame_interval_ms);
    result.ui_cpu_ms = sanitizeDuration(result.ui_cpu_ms);
    result.render_cpu_ms = sanitizeDuration(result.render_cpu_ms);
    result.total_cpu_ms = sanitizeDuration(result.total_cpu_ms);
    return result;
}

fn sanitizeDuration(value: f32) f32 {
    if (!std.math.isFinite(value) or value < 0) return 0;
    return @min(value, 10_000);
}

fn insertionSort(values: []f32) void {
    var index: usize = 1;
    while (index < values.len) : (index += 1) {
        const value = values[index];
        var insertion_index = index;
        while (insertion_index > 0 and values[insertion_index - 1] > value) : (insertion_index -= 1) {
            values[insertion_index] = values[insertion_index - 1];
        }
        values[insertion_index] = value;
    }
}

test "empty collector has a zero snapshot" {
    const collector: Collector = .{};
    try std.testing.expectEqual(@as(u16, 0), collector.snapshot().sample_count);
    try std.testing.expectEqual(@as(f32, 0), collector.snapshot().fps);
}

test "snapshot reports average percentile and peaks" {
    var collector: Collector = .{};
    for (1..21) |index| {
        _ = collector.record(.{
            .frame_interval_ms = @floatFromInt(index),
            .ui_cpu_ms = 1,
            .render_cpu_ms = 2,
            .total_cpu_ms = 4,
            .command_count = @intCast(index * 2),
            .semantic_node_count = 8,
        });
    }
    const result = collector.snapshot();
    try std.testing.expectEqual(@as(u16, 20), result.sample_count);
    try std.testing.expectApproxEqAbs(@as(f32, 10.5), result.average_frame_ms, 0.001);
    try std.testing.expectEqual(@as(f32, 19), result.p95_frame_ms);
    try std.testing.expectEqual(@as(f32, 20), result.slowest_frame_ms);
    try std.testing.expectEqual(@as(u32, 40), result.peak_command_count);
    try std.testing.expectEqual(@as(u32, 21), result.average_command_count);
    try std.testing.expectEqual(@as(u32, 8), result.average_semantic_node_count);
}

test "rolling window discards the oldest sample" {
    var collector: Collector = .{};
    for (0..max_samples) |_| _ = collector.record(.{ .frame_interval_ms = 10 });
    _ = collector.record(.{ .frame_interval_ms = 20 });
    const result = collector.snapshot();
    try std.testing.expectEqual(@as(u16, max_samples), result.sample_count);
    try std.testing.expectApproxEqAbs(@as(f32, (1190.0 + 20.0) / 120.0), result.average_frame_ms, 0.001);
    try std.testing.expectEqual(@as(f32, 20), result.slowest_frame_ms);
}

test "record publishes on a bounded cadence and sanitizes durations" {
    var collector: Collector = .{};
    try std.testing.expect(collector.record(.{ .frame_interval_ms = -1 }) == null);
    try std.testing.expect(collector.record(.{ .frame_interval_ms = std.math.nan(f32) }) == null);
    var published: ?Snapshot = null;
    for (0..31) |_| {
        if (collector.record(.{ .frame_interval_ms = 1000.0 / 60.0 })) |snapshot| published = snapshot;
    }
    try std.testing.expect(published != null);
    try std.testing.expect(published.?.average_frame_ms < 17);
}
