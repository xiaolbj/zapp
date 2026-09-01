const std = @import("std");
const Build = std.Build;

pub fn build(b: *Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const dep_sokol = b.dependency("sokol", .{
        .target = target,
        .optimize = optimize,
    });
    const dep_zclay = b.dependency("zclay", .{
        .target = target,
        .optimize = optimize,
    });
    const dep_fontstash = b.dependency("fontstash", .{});
    const dep_sokol_headers = b.dependency("sokol_headers", .{});

    const mod_zapp = b.addModule("zapp", .{
        .root_source_file = b.path("zapp.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "sokol", .module = dep_sokol.module("sokol") },
            .{ .name = "zclay", .module = dep_zclay.module("zclay") },
        },
    });
    mod_zapp.link_libc = true;
    mod_zapp.addIncludePath(dep_sokol.path("src/sokol/c"));
    mod_zapp.addIncludePath(dep_fontstash.path("src"));
    mod_zapp.addIncludePath(dep_sokol_headers.path("util"));
    mod_zapp.addCSourceFile(.{
        .file = b.path("src/text/fontstash_bridge.c"),
        .flags = fontstashCFlags(target.result),
    });

    const mod_main = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "sokol", .module = dep_sokol.module("sokol") },
            .{ .name = "zapp", .module = mod_zapp },
        },
    });

    const exe = b.addExecutable(.{
        .name = "zapp",
        .root_module = mod_main,
    });
    b.installArtifact(exe);

    const run = b.addRunArtifact(exe);
    if (b.args) |args| run.addArgs(args);
    b.step("run", "Run the desktop application").dependOn(&run.step);

    const check = b.step("check", "Compile the application without running it");
    check.dependOn(&exe.step);

    const unit_tests = b.addTest(.{
        .root_module = mod_zapp,
    });
    const run_unit_tests = b.addRunArtifact(unit_tests);
    b.step("test", "Run unit tests").dependOn(&run_unit_tests.step);
}

fn fontstashCFlags(target: std.Target) []const []const u8 {
    if (target.abi.isAndroid() or target.cpu.arch.isWasm()) {
        return &.{ "-std=c11", "-DSOKOL_GLES3" };
    }
    return switch (target.os.tag) {
        .windows => &.{ "-std=c11", "-DSOKOL_D3D11" },
        .macos, .ios => &.{ "-std=c11", "-DSOKOL_METAL" },
        else => &.{ "-std=c11", "-DSOKOL_GLCORE" },
    };
}
