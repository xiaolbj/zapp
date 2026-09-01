const sokol = @import("sokol");
const ui = @import("../ui/root.zig");

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
            .rectangle => drawRectangle(command.bounding_box, command.render_data.rectangle.background_color),
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

fn drawRectangle(bounds: @import("zclay").BoundingBox, color: @import("zclay").Color) void {
    const x0 = bounds.x;
    const y0 = bounds.y;
    const x1 = bounds.x + bounds.width;
    const y1 = bounds.y + bounds.height;
    const r = color[0] / 255;
    const g = color[1] / 255;
    const b = color[2] / 255;
    const a = color[3] / 255;

    sgl.beginQuads();
    sgl.v2fC4f(x0, y0, r, g, b, a);
    sgl.v2fC4f(x1, y0, r, g, b, a);
    sgl.v2fC4f(x1, y1, r, g, b, a);
    sgl.v2fC4f(x0, y1, r, g, b, a);
    sgl.end();
}
