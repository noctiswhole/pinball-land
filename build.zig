const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // box2d
    const box2d = b.dependency("box2d", .{
        .target = target,
        .optimize = optimize,
    });

    // Raylib deps
    const raylib_dep = b.dependency("raylib_zig", .{
        .target = target,
        .optimize = optimize,
    });

    const raylib = raylib_dep.module("raylib");
    const raygui = raylib_dep.module("raygui");
    const raylib_artifact = raylib_dep.artifact("raylib");

    //sqlite
    const sqlite = b.dependency("sqlite", .{
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "kirbys_pinball_land_dx_zig",
        // .use_llvm = true,
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "raylib", .module = raylib },
                .{ .name = "raygui", .module = raygui },
                .{ .name = "sqlite", .module = sqlite.module("sqlite") },
            },
        }),
    });
    exe.addIncludePath(box2d.path("."));
    exe.linkLibrary(box2d.artifact("box2d"));
    exe.linkLibrary(raylib_artifact);
    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");

    // Editor setup
    const dvui_dep = b.dependency("dvui", .{
        .target = target,
        .optimize = optimize,
        .backend = .raylib_zig,
    });
    const backend_mod = dvui_dep.module("raylib_zig");
    backend_mod.addImport("raylib", raylib); // from your raylib dependency
    backend_mod.addImport("raygui", raygui);

    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());

    const editor_exe = b.addExecutable(.{
        .name = "kirbys_pinball_land_dx_editor",
        // .use_llvm = true,
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/editor.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "raylib", .module = raylib },
                .{ .name = "raygui", .module = raygui },
                .{ .name = "dvui", .module = dvui_dep.module("dvui_raylib_zig")},
                .{ .name = "raylib-zig-backend", .module = backend_mod},
                .{ .name = "sqlite", .module = sqlite.module("sqlite") },
            },
        }),
    });

    const editor_run_step = b.step("editor", "Run the editor");

    const editor_run_cmd = b.addRunArtifact(editor_exe);
    editor_run_step.dependOn(&editor_run_cmd.step);
    editor_run_cmd.step.dependOn(b.getInstallStep());
    b.installArtifact(editor_exe);
    editor_exe.addIncludePath(box2d.path("."));
    editor_exe.linkLibrary(box2d.artifact("box2d"));
    editor_exe.linkLibrary(raylib_artifact);
    b.installArtifact(editor_exe);

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });

    const run_exe_tests = b.addRunArtifact(exe_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_exe_tests.step);
}
