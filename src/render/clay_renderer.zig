const std = @import("std");
const sokol = @import("sokol");
const ui = @import("../ui/root.zig");
const clay = @import("zclay");

const sg = sokol.gfx;
const sgl = sokol.gl;
const sglue = sokol.glue;
const slog = sokol.log;
const font = @import("../text/font.zig");

pub const ClayRenderer = struct {
    pass_action: sg.PassAction = .{},

    pub fn setup(self: *ClayRenderer) bool {
        sg.setup(.{
            .environment = sglue.environment(),
            .logger = .{ .func = slog.func },
        });
        sgl.setup(.{
            .depth_format = .NONE,
            .logger = .{ .func = slog.func },
        });
        if (!font.setup()) return false;
        self.pass_action.colors[0].load_action = .CLEAR;
        return true;
    }

    pub fn draw(self: *ClayRenderer, frame: ui.Frame) void {
        const color = frame.clear_color;
        self.pass_action.colors[0].clear_value = .{
            .r = color.r,
            .g = color.g,
            .b = color.b,
            .a = color.a,
        };

        recordCommands(frame);

        sg.beginPass(.{
            .action = self.pass_action,
            .swapchain = sglue.swapchain(),
        });
        sgl.draw();
        sg.endPass();
        sg.commit();
    }

    pub fn shutdown(_: *ClayRenderer) void {
        font.shutdown();
        sgl.shutdown();
        sg.shutdown();
    }
};

fn recordCommands(frame: ui.Frame) void {
    const width = sokol.app.widthf();
    const height = sokol.app.heightf();

    sgl.defaults();
    sgl.matrixModeProjection();
    sgl.loadIdentity();
    sgl.ortho(0, width, height, 0, -1, 1);
    sgl.matrixModeModelview();
    sgl.loadIdentity();

    for (frame.commands) |command| {
        switch (command.command_type) {
            .rectangle => drawRectangle(command.bounding_box, command.render_data.rectangle),
            .border => drawBorder(command.bounding_box, command.render_data.border),
            .text => font.draw(command.bounding_box, command.render_data.text),
            .scissor_start => {
                const bounds = command.bounding_box;
                sgl.scissorRectf(bounds.x, bounds.y, bounds.width, bounds.height, true);
            },
            .scissor_end => sgl.scissorRectf(0, 0, width, height, true),
            else => {},
        }
    }
    font.flush();
}

fn drawBorder(bounds: clay.BoundingBox, data: clay.BorderRenderData) void {
    const color = data.color;
    const r = color[0] / 255;
    const g = color[1] / 255;
    const b = color[2] / 255;
    const a = color[3] / 255;
    const x0 = bounds.x;
    const y0 = bounds.y;
    const x1 = bounds.x + bounds.width;
    const y1 = bounds.y + bounds.height;
    const left: f32 = @floatFromInt(data.width.left);
    const right: f32 = @floatFromInt(data.width.right);
    const top: f32 = @floatFromInt(data.width.top);
    const bottom: f32 = @floatFromInt(data.width.bottom);

    if (top > 0) drawQuad(x0, y0, x1, y0 + top, r, g, b, a);
    if (bottom > 0) drawQuad(x0, y1 - bottom, x1, y1, r, g, b, a);
    if (left > 0) drawQuad(x0, y0 + top, x0 + left, y1 - bottom, r, g, b, a);
    if (right > 0) drawQuad(x1 - right, y0 + top, x1, y1 - bottom, r, g, b, a);
}

fn drawRectangle(bounds: clay.BoundingBox, data: clay.RectangleRenderData) void {
    const x0 = bounds.x;
    const y0 = bounds.y;
    const x1 = bounds.x + bounds.width;
    const y1 = bounds.y + bounds.height;
    const color = data.background_color;
    const r = color[0] / 255;
    const g = color[1] / 255;
    const b = color[2] / 255;
    const a = color[3] / 255;
    const requested_radius = @min(
        @min(data.corner_radius.top_left, data.corner_radius.top_right),
        @min(data.corner_radius.bottom_left, data.corner_radius.bottom_right),
    );
    const radius = @min(@max(requested_radius, 0), @min(bounds.width, bounds.height) * 0.5);

    if (radius <= 0.01) {
        drawQuad(x0, y0, x1, y1, r, g, b, a);
        return;
    }

    drawQuad(x0 + radius, y0, x1 - radius, y1, r, g, b, a);
    drawQuad(x0, y0 + radius, x0 + radius, y1 - radius, r, g, b, a);
    drawQuad(x1 - radius, y0 + radius, x1, y1 - radius, r, g, b, a);

    const pi: f32 = @floatCast(std.math.pi);
    drawCorner(x0 + radius, y0 + radius, radius, pi, pi * 1.5, r, g, b, a);
    drawCorner(x1 - radius, y0 + radius, radius, pi * 1.5, pi * 2, r, g, b, a);
    drawCorner(x1 - radius, y1 - radius, radius, 0, pi * 0.5, r, g, b, a);
    drawCorner(x0 + radius, y1 - radius, radius, pi * 0.5, pi, r, g, b, a);
}

fn drawQuad(x0: f32, y0: f32, x1: f32, y1: f32, r: f32, g: f32, b: f32, a: f32) void {
    sgl.beginQuads();
    sgl.v2fC4f(x0, y0, r, g, b, a);
    sgl.v2fC4f(x1, y0, r, g, b, a);
    sgl.v2fC4f(x1, y1, r, g, b, a);
    sgl.v2fC4f(x0, y1, r, g, b, a);
    sgl.end();
}

fn drawCorner(cx: f32, cy: f32, radius: f32, start: f32, end: f32, r: f32, g: f32, b: f32, a: f32) void {
    const segments = 6;
    sgl.beginTriangles();
    sgl.c4f(r, g, b, a);
    for (0..segments) |index| {
        const t0: f32 = @floatFromInt(index);
        const t1: f32 = @floatFromInt(index + 1);
        const angle0 = start + (end - start) * (t0 / segments);
        const angle1 = start + (end - start) * (t1 / segments);
        sgl.v2f(cx, cy);
        sgl.v2f(cx + @cos(angle0) * radius, cy + @sin(angle0) * radius);
        sgl.v2f(cx + @cos(angle1) * radius, cy + @sin(angle1) * radius);
    }
    sgl.end();
}
