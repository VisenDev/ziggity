const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "dev",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    //const zigtoml = b.dependency("zigtoml", .{
    //    .target = target,
    //    .optimize = optimize,
    //});
    //exe.addModule("toml", zigtoml.module("toml"));

    //link lua
    const ziglua = b.dependency("ziglua", .{
        .target = target,
        .optimize = optimize,
    });

    // add the ziglua module and lua artifact
    exe.root_module.addImport("ziglua", ziglua.module("ziglua"));
    //exe.linkLibrary(ziglua.artifact("lua"));
    //exe.linkLibrary(ziglua.artifact("lua"));

    const ray = b.dependency("raylib", .{ .target = target, .optimize = optimize });
    exe.linkLibrary(ray.artifact("raylib"));

    //find raygui.h
    exe.addIncludePath(.{ .path = "lib" });

    //flags to find raylib correctly
    const cflags = [_][]const u8{ "-D RAYGUI_IMPLEMENTATION", "-lraylib" };
    exe.addCSourceFile(.{ .file = .{
        .path = "lib/raygui.c",
    }, .flags = &cflags });
    b.installArtifact(exe);

    //=============INSTALL GAME FILES===========
    b.installDirectory(.{ .source_dir = .{ .path = "data" }, .install_dir = .bin, .install_subdir = "data" });

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    //=================PASS EXTRA ARGS================
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    //================CREATE RUN BUILD STEP=============
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Creates a step for unit testing. This only builds the test executable
    // but does not run it.
    var unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    unit_tests.linkLibC();
    unit_tests.step.dependOn((b.getInstallStep()));
    unit_tests.linkLibrary(ray.artifact("raylib"));

    //unit_tests.addModule("toml", zigtoml.module("toml"));

    //find raygui.h
    unit_tests.addIncludePath(.{ .path = "lib" });

    //link lua
    //
    unit_tests.root_module.addImport("ziglua", ziglua.module("ziglua"));

    unit_tests.addCSourceFile(.{ .file = .{
        .path = "lib/raygui.c",
    }, .flags = &cflags });

    var run_unit_tests = b.addRunArtifact(unit_tests);
    run_unit_tests.has_side_effects = true;
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}
