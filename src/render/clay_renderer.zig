const std = @import("std");
const sokol = @import("sokol");
const ui = @import("../ui/root.zig");
const clay = @import("zclay");

const sg = sokol.gfx;
const sgl = sokol.gl;
const sglue = sokol.glue;
const slog = sokol.log;
const font = @import("../text/font.zig");
const image_view = @import("../ui/widgets/image_view.zig");
const image_registry = @import("image_registry.zig");

pub const ClayRenderer = struct {
    pass_action: sg.PassAction = .{},
    images: image_registry.Registry = .{},

    pub fn setup(self: *ClayRenderer) bool {
        sg.setup(.{
            .environment = sglue.environment(),
            .logger = .{ .func = slog.func },
        });
        sgl.setup(.{
            .depth_format = .NONE,
            .logger = .{ .func = slog.func },
        });
        if (!self.images.setup()) {
            sgl.shutdown();
            sg.shutdown();
            return false;
        }
        if (!font.setup()) {
            self.images.shutdown();
            sgl.shutdown();
            sg.shutdown();
            return false;
        }
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

        self.recordCommands(frame);

        sg.beginPass(.{
            .action = self.pass_action,
            .swapchain = sglue.swapchain(),
        });
        sgl.draw();
        sg.endPass();
        sg.commit();
    }

    pub fn shutdown(self: *ClayRenderer) void {
        font.shutdown();
        self.images.shutdown();
        sgl.shutdown();
        sg.shutdown();
    }

    fn recordCommands(self: *ClayRenderer, frame: ui.Frame) void {
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
                .image => self.drawImage(command.bounding_box, command.render_data.image),
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

    fn drawImage(self: *ClayRenderer, bounds: clay.BoundingBox, data: clay.ImageRenderData) void {
        const raw_source = data.image_data orelse return;
        const source: *const image_view.Source = @ptrCast(@alignCast(raw_source));
        const texture = self.images.resolve(source.resource) orelse return;
        const placement = imagePlacement(bounds, source.*);
        const tint = imageTint(data.background_color);
        const requested_radius = @min(
            @min(data.corner_radius.top_left, data.corner_radius.top_right),
            @min(data.corner_radius.bottom_left, data.corner_radius.bottom_right),
        );
        sgl.enableTexture();
        sgl.texture(texture.view, texture.sampler);
        drawTexturedRoundedQuad(placement, requested_radius, tint);
        sgl.disableTexture();
    }
};

const ImagePlacement = struct {
    bounds: clay.BoundingBox,
    u0: f32 = 0,
    v0: f32 = 0,
    u1: f32 = 1,
    v1: f32 = 1,
};

const Tint = struct {
    r: f32,
    g: f32,
    b: f32,
    a: f32,
};

fn imagePlacement(container: clay.BoundingBox, source: image_view.Source) ImagePlacement {
    if (container.width <= 0 or container.height <= 0 or source.pixel_width <= 0 or source.pixel_height <= 0) {
        return .{ .bounds = container };
    }
    if (source.fit == .stretch) return .{ .bounds = container };

    const source_aspect = source.pixel_width / source.pixel_height;
    const container_aspect = container.width / container.height;
    if (source.fit == .contain) {
        var result = container;
        if (container_aspect > source_aspect) {
            result.width = container.height * source_aspect;
            result.x += (container.width - result.width) * 0.5;
        } else {
            result.height = container.width / source_aspect;
            result.y += (container.height - result.height) * 0.5;
        }
        return .{ .bounds = result };
    }

    var placement: ImagePlacement = .{ .bounds = container };
    if (container_aspect > source_aspect) {
        const visible_fraction = source_aspect / container_aspect;
        placement.v0 = (1 - visible_fraction) * 0.5;
        placement.v1 = 1 - placement.v0;
    } else {
        const visible_fraction = container_aspect / source_aspect;
        placement.u0 = (1 - visible_fraction) * 0.5;
        placement.u1 = 1 - placement.u0;
    }
    return placement;
}

fn imageTint(color: clay.Color) Tint {
    if (color[0] == 0 and color[1] == 0 and color[2] == 0 and color[3] == 0) {
        return .{ .r = 1, .g = 1, .b = 1, .a = 1 };
    }
    return .{
        .r = color[0] / 255,
        .g = color[1] / 255,
        .b = color[2] / 255,
        .a = color[3] / 255,
    };
}

fn drawTexturedRoundedQuad(placement: ImagePlacement, requested_radius: f32, tint: Tint) void {
    const bounds = placement.bounds;
    const x0 = bounds.x;
    const y0 = bounds.y;
    const x1 = bounds.x + bounds.width;
    const y1 = bounds.y + bounds.height;
    const radius = @min(@max(requested_radius, 0), @min(bounds.width, bounds.height) * 0.5);
    if (radius <= 0.01) {
        drawTexturedQuad(placement, x0, y0, x1, y1, tint);
        return;
    }

    drawTexturedQuad(placement, x0 + radius, y0, x1 - radius, y1, tint);
    drawTexturedQuad(placement, x0, y0 + radius, x0 + radius, y1 - radius, tint);
    drawTexturedQuad(placement, x1 - radius, y0 + radius, x1, y1 - radius, tint);

    const pi: f32 = @floatCast(std.math.pi);
    drawTexturedCorner(placement, x0 + radius, y0 + radius, radius, pi, pi * 1.5, tint);
    drawTexturedCorner(placement, x1 - radius, y0 + radius, radius, pi * 1.5, pi * 2, tint);
    drawTexturedCorner(placement, x1 - radius, y1 - radius, radius, 0, pi * 0.5, tint);
    drawTexturedCorner(placement, x0 + radius, y1 - radius, radius, pi * 0.5, pi, tint);
}

fn drawTexturedQuad(placement: ImagePlacement, x0: f32, y0: f32, x1: f32, y1: f32, tint: Tint) void {
    sgl.beginQuads();
    texturedVertex(placement, x0, y0, tint);
    texturedVertex(placement, x1, y0, tint);
    texturedVertex(placement, x1, y1, tint);
    texturedVertex(placement, x0, y1, tint);
    sgl.end();
}

fn drawTexturedCorner(
    placement: ImagePlacement,
    cx: f32,
    cy: f32,
    radius: f32,
    start: f32,
    end: f32,
    tint: Tint,
) void {
    const segments = 8;
    sgl.beginTriangles();
    for (0..segments) |index| {
        const t0: f32 = @floatFromInt(index);
        const t1: f32 = @floatFromInt(index + 1);
        const angle0 = start + (end - start) * (t0 / segments);
        const angle1 = start + (end - start) * (t1 / segments);
        texturedVertex(placement, cx, cy, tint);
        texturedVertex(placement, cx + @cos(angle0) * radius, cy + @sin(angle0) * radius, tint);
        texturedVertex(placement, cx + @cos(angle1) * radius, cy + @sin(angle1) * radius, tint);
    }
    sgl.end();
}

fn texturedVertex(placement: ImagePlacement, x: f32, y: f32, tint: Tint) void {
    const bounds = placement.bounds;
    const tx = if (bounds.width > 0) (x - bounds.x) / bounds.width else 0;
    const ty = if (bounds.height > 0) (y - bounds.y) / bounds.height else 0;
    const u = placement.u0 + (placement.u1 - placement.u0) * tx;
    const v = placement.v0 + (placement.v1 - placement.v0) * ty;
    sgl.v2fT2fC4f(x, y, u, v, tint.r, tint.g, tint.b, tint.a);
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

test "image placement supports stretch contain and cover" {
    const container: clay.BoundingBox = .{ .x = 10, .y = 20, .width = 100, .height = 100 };

    const stretched = imagePlacement(container, .{
        .resource = .demo_hero,
        .pixel_width = 200,
        .pixel_height = 100,
        .fit = .stretch,
    });
    try std.testing.expectEqual(container, stretched.bounds);
    try std.testing.expectEqual(@as(f32, 0), stretched.u0);
    try std.testing.expectEqual(@as(f32, 1), stretched.u1);

    const contained = imagePlacement(container, .{
        .resource = .demo_hero,
        .pixel_width = 200,
        .pixel_height = 100,
        .fit = .contain,
    });
    try std.testing.expectEqual(@as(f32, 10), contained.bounds.x);
    try std.testing.expectEqual(@as(f32, 45), contained.bounds.y);
    try std.testing.expectEqual(@as(f32, 100), contained.bounds.width);
    try std.testing.expectEqual(@as(f32, 50), contained.bounds.height);

    const covered = imagePlacement(container, .{
        .resource = .demo_hero,
        .pixel_width = 200,
        .pixel_height = 100,
        .fit = .cover,
    });
    try std.testing.expectEqual(container, covered.bounds);
    try std.testing.expectApproxEqAbs(@as(f32, 0.25), covered.u0, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.75), covered.u1, 0.0001);
    try std.testing.expectEqual(@as(f32, 0), covered.v0);
    try std.testing.expectEqual(@as(f32, 1), covered.v1);
}

test "zero image tint preserves source colors" {
    const untinted = imageTint(.{ 0, 0, 0, 0 });
    try std.testing.expectEqual(@as(f32, 1), untinted.r);
    try std.testing.expectEqual(@as(f32, 1), untinted.g);
    try std.testing.expectEqual(@as(f32, 1), untinted.b);
    try std.testing.expectEqual(@as(f32, 1), untinted.a);

    const tinted = imageTint(.{ 255, 128, 0, 64 });
    try std.testing.expectEqual(@as(f32, 1), tinted.r);
    try std.testing.expectApproxEqAbs(@as(f32, 128.0 / 255.0), tinted.g, 0.0001);
    try std.testing.expectEqual(@as(f32, 0), tinted.b);
    try std.testing.expectApproxEqAbs(@as(f32, 64.0 / 255.0), tinted.a, 0.0001);
}
