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

    const zigtoml = b.dependency("zigtoml", .{
        .target = target,
        .optimize = optimize,
    });
    exe.addModule("toml", zigtoml.module("toml"));

    //link lua
    const ziglua = b.dependency("ziglua", .{
        .target = target,
        .optimize = optimize,
    });

    // add the ziglua module and lua artifact
    exe.addModule("ziglua", ziglua.module("ziglua"));
    exe.linkLibrary(ziglua.artifact("lua"));

    //link raylib
    exe.linkSystemLibrary("raylib");
    exe.linkLibC();

    //find raygui.h
    exe.addIncludePath(.{ .path = "lib" });

    //flags to find raylib correctly
    const cflags = [_][]const u8{
        "-D RAYGUI_IMPLEMENTATION",
        "-I/usr/local/Cellar/raylib/4.5.0/include",
        "-L/usr/local/Cellar/raylib/4.5.0/lib",
        "-lraylib",
    };
    exe.addCSourceFile(.{
        .file = .{
            .path = "lib/raygui.c",
        },
        .flags = &cflags,
    });
    b.installArtifact(exe);

    //=============INSTALL GAME FILES===========
    b.installDirectory(.{ .source_dir = .{ .path = "game-files" }, .install_dir = .bin, .install_subdir = "game-files" });

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
    unit_tests.linkSystemLibrary("raylib");
    //find raygui.h
    unit_tests.addIncludePath(.{ .path = "lib" });

    //link unit tests with toml to json
    unit_tests.addIncludePath(.{ .path = "toml-to-json" });
    unit_tests.addLibraryPath(.{ .path = "toml-to-json/target/release" });
    unit_tests.linkSystemLibrary("toml_to_json");

    //link lua
    unit_tests.addModule("ziglua", ziglua.module("ziglua"));
    unit_tests.linkLibrary(ziglua.artifact("lua"));

    unit_tests.addCSourceFile(.{
        .file = .{
            .path = "lib/raygui.c",
        },
        .flags = &cflags,
    });

    var run_unit_tests = b.addRunArtifact(unit_tests);
    run_unit_tests.has_side_effects = true;
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}
