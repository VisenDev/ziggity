const std = @import("std");
//const raylib_dep = @import("raylib");

pub fn build(b: *std.Build) !void {
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

    const exe_test = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    //================ADD DVUI======================
    const dvui = b.dependency("dvui", .{ .target = target, .optimize = optimize });
    exe.root_module.addImport("dvui", dvui.module("dvui_raylib"));
    exe_check.root_module.addImport("dvui", dvui.module("dvui_raylib"));
    exe_test.root_module.addImport("dvui", dvui.module("dvui_raylib"));

    //================ADD RAYLIBBACKEND======================
    //exe.root_module.addImport("RaylibBackend", dvui.module("RaylibBackend"));
    //exe_check.root_module.addImport("RaylibBackend", dvui.module("RaylibBackend"));
    //exe_test.root_module.addImport("RaylibBackend", dvui.module("RaylibBackend"));

    //================ADD ZIGLUA====================
    const ziglua = b.dependency("ziglua", .{ .target = target, .optimize = optimize });
    exe.root_module.addImport("ziglua", ziglua.module("ziglua"));
    exe_check.root_module.addImport("ziglua", ziglua.module("ziglua"));
    exe_test.root_module.addImport("ziglua", ziglua.module("ziglua"));

    //===============DEFINE LUA TYPES=====================
    const define_exe = b.addExecutable(.{
        .name = "define",
        .root_source_file = b.path("src/define_exe.zig"),
        .target = target,
    });
    define_exe.root_module.addImport("ziglua", ziglua.module("ziglua"));

    var run_define_exe = b.addRunArtifact(define_exe);
    run_define_exe.addFileArg(b.path("data/lua/definitions.lua"));

    const define_step = b.step("define", "");
    define_step.dependOn(&run_define_exe.step);

    //================LINK RAYLIB===================
    const maybe_ray = dvui.builder.lazyDependency("raylib", .{ .target = target, .optimize = optimize });
    if (maybe_ray) |ray| {
        exe.linkLibrary(ray.artifact("raylib"));
        exe_check.linkLibrary(ray.artifact("raylib"));
        exe_test.linkLibrary(ray.artifact("raylib"));
        define_exe.linkLibrary(ray.artifact("raylib"));

        const glad_path = ray.path("src/external");
        exe.addIncludePath(glad_path);
    }

    //================FIND GLAD.H===================
    // const glad_path = b.dependency("raylib", .{}).path("src/external");
    // exe.addIncludePath(glad_path);
    // exe.addIncludePath(glad_path);
    // exe.addIncludePath(glad_path);

    //================FIND STYLES===================
    //const rguilayout = b.dependency("rguilayout", .{ .target = target, .optimize = optimize });
    //const styles_folder = rguilayout.path("src/styles");
    //exe.addIncludePath(styles_folder);
    //exe_check.addIncludePath(styles_folder);
    //exe_test.addIncludePath(styles_folder);

    //=============INSTALL TO OUTPUT DIR===========
    b.installArtifact(exe);
    b.installDirectory(.{ .source_dir = b.path("data"), .install_dir = .bin, .install_subdir = "data" });

    //=============TRIGGER EXECUTION================
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    const run_exe_test = b.addRunArtifact(exe_test);
    run_exe_test.step.dependOn((b.getInstallStep()));

    //================TYPES OF BUILD STEPS=============
    const run_step = b.step("run", "Run the game");
    run_step.dependOn(&run_cmd.step);

    const check_step = b.step("check", "Check if the game compiles");
    check_step.dependOn(&exe_check.step);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_test.step);
}
