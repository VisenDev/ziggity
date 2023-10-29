const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = .Debug;

    const exe = b.addExecutable(.{
        .name = "dev",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

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

    // =============TOML TO JSON LINKING=================
    //const rust_compile = b.addSystemCommand(&[_][]const u8{ "cargo", "build", "--release", "--manifest-path=toml-to-json/Cargo.toml" });
    //b.default_step.dependOn(&rust_compile.step);

    //exe.addIncludePath(.{ .path = "toml-to-json" });
    //exe.addLibraryPath(.{ .path = "toml-to-json/target/release" });
    //exe.linkSystemLibrary("toml_to_json");
    //const ztoml = ztoml_dep.artifact("ztoml");
    //exe.linkLibrary(ztoml);
    const ztoml_dep = b.dependency("ztoml", .{});
    b.default_step.dependOn(ztoml_dep.builder.default_step);
    exe.addModule("ztoml", ztoml_dep.module("ztoml"));
    @import("ztoml").link(ztoml_dep.builder, exe);

    //installing

    b.installDirectory(.{ .source_dir = .{ .path = "game-files" }, .install_dir = .bin, .install_subdir = "game-files" });

    const run_cmd = b.addRunArtifact(exe);

    // By making the run step depend on the install step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    // This is not necessary, however, if the application depends on other installed
    // files, this ensures they will be present and in the expected location.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
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

    unit_tests.addCSourceFile(.{
        .file = .{
            .path = "lib/raygui.c",
        },
        .flags = &cflags,
    });

    var run_unit_tests = b.addRunArtifact(unit_tests);
    run_unit_tests.has_side_effects = true;

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}
