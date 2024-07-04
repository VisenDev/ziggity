const std = @import("std");
const raylib_dep = @import("raylib");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "dev",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    const exe_check = b.addExecutable(.{
        .name = "dev",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    const check = b.step("check", "Check if foo compiles");
    check.dependOn(&exe_check.step);

    //link lua
    const ziglua = b.dependency("ziglua", .{ .target = target, .optimize = optimize });
    exe.root_module.addImport("ziglua", ziglua.module("ziglua"));
    exe_check.root_module.addImport("ziglua", ziglua.module("ziglua"));

    //the actual raylib import
    const ray = try raylib_dep.addRaylib(b, target, optimize, .{ .raygui = true });
    exe.linkLibrary(ray);
    exe_check.linkLibrary(ray);

    //flags to find styledark.h correctly
    exe.addIncludePath(b.path("lib"));
    exe_check.addIncludePath(b.path("lib"));

    //install
    b.installArtifact(exe);

    //=============INSTALL GAME FILES===========
    b.installDirectory(.{ .source_dir = b.path("data"), .install_dir = .bin, .install_subdir = "data" });

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
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    unit_tests.linkLibC();
    unit_tests.step.dependOn((b.getInstallStep()));
    //unit_tests.linkLibrary(ray.artifact("raylib"));

    //unit_tests.addModule("toml", zigtoml.module("toml"));

    //find raygui.h
    unit_tests.addIncludePath(b.path("lib"));

    //link lua
    //
    unit_tests.root_module.addImport("ziglua", ziglua.module("ziglua"));

    //unit_tests.addCSourceFile(.{ .file = b.path("lib/raygui.c"), .flags = &cflags });

    var run_unit_tests = b.addRunArtifact(unit_tests);
    run_unit_tests.has_side_effects = true;
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}
