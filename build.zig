const std = @import("std");
const Build = std.Build;

const AndroidAbi = enum {
    @"arm64-v8a",
    x86_64,
};

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
    mod_zapp.addIncludePath(b.path("third_party/stb"));
    mod_zapp.addCSourceFile(.{
        .file = b.path("src/text/fontstash_bridge.c"),
        .flags = fontstashCFlags(target.result),
    });
    mod_zapp.addCSourceFile(.{
        .file = b.path("src/render/image_decode_bridge.c"),
        .flags = &.{ "-std=c11", "-fvisibility=hidden" },
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

    configureAndroidBuild(b, optimize, dep_fontstash, dep_sokol_headers);
}

fn configureAndroidBuild(
    b: *Build,
    optimize: std.builtin.OptimizeMode,
    dep_fontstash: *Build.Dependency,
    dep_sokol_headers: *Build.Dependency,
) void {
    const android_step = b.step("android-lib", "Build libzapp.so for an Android ABI");
    const ndk_root = b.option([]const u8, "android-ndk", "Absolute path to the Android NDK") orelse {
        const missing = b.addFail("android-lib requires -Dandroid-ndk=<path-to-ndk>");
        android_step.dependOn(&missing.step);
        return;
    };
    const abi = b.option(AndroidAbi, "android-abi", "Android ABI: arm64-v8a or x86_64") orelse .@"arm64-v8a";
    const api_level = b.option(u32, "android-api", "Android API level") orelse 26;
    const output_dir = b.option(
        []const u8,
        "android-output-dir",
        "Install subdirectory for Android libraries",
    ) orelse "android";
    const split_debug_symbols = b.option(
        bool,
        "android-split-debug-symbols",
        "Extract Android debug symbols and install a stripped library",
    ) orelse false;
    const symbols_dir = b.option(
        []const u8,
        "android-symbols-dir",
        "Install subdirectory for separated Android debug symbols",
    ) orelse "android-symbols";
    const target = b.resolveTargetQuery(.{
        .cpu_arch = switch (abi) {
            .@"arm64-v8a" => .aarch64,
            .x86_64 => .x86_64,
        },
        .os_tag = .linux,
        .abi = .android,
        .android_api_level = api_level,
    });
    const ndk_host = switch (@import("builtin").os.tag) {
        .windows => "windows-x86_64",
        .macos => "darwin-x86_64",
        else => "linux-x86_64",
    };
    const target_triple = switch (abi) {
        .@"arm64-v8a" => "aarch64-linux-android",
        .x86_64 => "x86_64-linux-android",
    };
    const sysroot = b.pathJoin(&.{ ndk_root, "toolchains", "llvm", "prebuilt", ndk_host, "sysroot" });
    const ndk_include = Build.LazyPath{ .cwd_relative = b.pathJoin(&.{ sysroot, "usr", "include" }) };
    const ndk_target_include = Build.LazyPath{ .cwd_relative = b.pathJoin(&.{ sysroot, "usr", "include", target_triple }) };

    const dep_sokol = b.dependency("sokol", .{
        .target = target,
        .optimize = optimize,
        .dont_link_system_libs = true,
    });
    const sokol_clib = dep_sokol.artifact("sokol_clib");
    sokol_clib.root_module.pic = true;
    if (split_debug_symbols) sokol_clib.root_module.strip = false;
    sokol_clib.root_module.addSystemIncludePath(ndk_include);
    sokol_clib.root_module.addSystemIncludePath(ndk_target_include);
    const dep_zclay = b.dependency("zclay", .{
        .target = target,
        .optimize = optimize,
    });
    const mod_zapp = b.addModule("zapp_android", .{
        .root_source_file = b.path("zapp.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "sokol", .module = dep_sokol.module("sokol") },
            .{ .name = "zclay", .module = dep_zclay.module("zclay") },
        },
    });
    mod_zapp.link_libc = true;
    if (split_debug_symbols) mod_zapp.strip = false;
    mod_zapp.addSystemIncludePath(ndk_include);
    mod_zapp.addSystemIncludePath(ndk_target_include);
    mod_zapp.addIncludePath(dep_sokol.path("src/sokol/c"));
    mod_zapp.addIncludePath(dep_fontstash.path("src"));
    mod_zapp.addIncludePath(dep_sokol_headers.path("util"));
    mod_zapp.addIncludePath(b.path("third_party/stb"));
    mod_zapp.addCSourceFile(.{
        .file = b.path("src/text/fontstash_bridge.c"),
        .flags = fontstashCFlags(target.result),
    });
    mod_zapp.addCSourceFile(.{
        .file = b.path("src/render/image_decode_bridge.c"),
        .flags = &.{ "-std=c11", "-fvisibility=hidden" },
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
    mod_main.pic = true;
    mod_main.link_libc = true;
    if (split_debug_symbols) mod_main.strip = false;
    mod_main.addSystemIncludePath(ndk_include);
    mod_main.addSystemIncludePath(ndk_target_include);
    mod_main.addCSourceFile(.{
        .file = b.path("src/platform/android_bridge.c"),
        .flags = &.{ "-std=c11", "-fvisibility=default" },
    });
    mod_main.addCSourceFile(.{
        .file = b.path("src/platform/android_crash_report.c"),
        .flags = &.{ "-std=c11", "-fvisibility=hidden", "-Wall", "-Wextra", "-Werror" },
    });
    const library = b.addLibrary(.{
        .name = "zapp",
        .linkage = .static,
        .root_module = mod_main,
    });
    library.bundle_compiler_rt = true;
    const clang_path = b.pathJoin(&.{
        ndk_root,
        "toolchains",
        "llvm",
        "prebuilt",
        ndk_host,
        "bin",
        if (@import("builtin").os.tag == .windows) "clang.exe" else "clang",
    });
    const linker = b.addSystemCommand(&.{ clang_path, b.fmt("--target={s}{d}", .{ target_triple, api_level }) });
    linker.addArgs(&.{
        "-shared",
        "-fPIC",
        "-Wl,-soname,libzapp.so",
        "-Wl,--build-id=sha1",
        "-Wl,--no-undefined",
        "-Xlinker",
        "--version-script",
        "-Xlinker",
    });
    linker.addFileArg(b.path("src/platform/android_exports.map"));
    linker.addArg("-Wl,--whole-archive");
    linker.addArtifactArg(library);
    for (library.getCompileDependencies(false)) |dependency| {
        if (dependency != library and dependency.kind == .lib) {
            dependency.root_module.pic = true;
            if (split_debug_symbols) dependency.root_module.strip = false;
            linker.addArtifactArg(dependency);
        }
    }
    linker.addArgs(&.{
        "-Wl,--no-whole-archive",
        "-lGLESv3",
        "-lEGL",
        "-landroid",
        "-llog",
        "-laaudio",
        "-lm",
        "-ldl",
        "-o",
    });
    const shared_library = linker.addOutputFileArg("libzapp.so");
    if (split_debug_symbols) {
        const tool_extension = if (@import("builtin").os.tag == .windows) ".exe" else "";
        const objcopy_path = b.pathJoin(&.{
            ndk_root,
            "toolchains",
            "llvm",
            "prebuilt",
            ndk_host,
            "bin",
            b.fmt("llvm-objcopy{s}", .{tool_extension}),
        });
        const strip_path = b.pathJoin(&.{
            ndk_root,
            "toolchains",
            "llvm",
            "prebuilt",
            ndk_host,
            "bin",
            b.fmt("llvm-strip{s}", .{tool_extension}),
        });
        const extract_debug = b.addSystemCommand(&.{
            objcopy_path,
            "--only-keep-debug",
            "--compress-debug-sections=zlib",
        });
        extract_debug.addFileArg(shared_library);
        const debug_symbols = extract_debug.addOutputFileArg("libzapp.so.debug");

        const strip_library = b.addSystemCommand(&.{ strip_path, "--strip-unneeded", "-o" });
        const stripped_library = strip_library.addOutputFileArg("libzapp.so");
        strip_library.addFileArg(shared_library);

        const add_debug_link = b.addSystemCommand(&.{ objcopy_path, "--add-gnu-debuglink" });
        add_debug_link.addFileArg(debug_symbols);
        add_debug_link.addFileArg(stripped_library);
        const packaged_library = add_debug_link.addOutputFileArg("libzapp.so");

        const install_library = b.addInstallFile(
            packaged_library,
            b.fmt("{s}/{s}/libzapp.so", .{ output_dir, @tagName(abi) }),
        );
        const install_symbols = b.addInstallFile(
            debug_symbols,
            b.fmt("{s}/{s}/libzapp.so.debug", .{ symbols_dir, @tagName(abi) }),
        );
        android_step.dependOn(&install_library.step);
        android_step.dependOn(&install_symbols.step);
    } else {
        const install = b.addInstallFile(
            shared_library,
            b.fmt("{s}/{s}/libzapp.so", .{ output_dir, @tagName(abi) }),
        );
        android_step.dependOn(&install.step);
    }
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
