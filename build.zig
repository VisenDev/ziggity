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

    //================ADD PROFILER=====================
    const profiler = b.dependency("profiler", .{ .target = target, .optimize = optimize });

    exe.root_module.addImport("profiler", profiler.module("profiler"));
    exe_check.root_module.addImport("profiler", profiler.module("profiler"));
    exe_test.root_module.addImport("profiler", profiler.module("profiler"));

    //================ADD DVUI======================
    const dvui = b.dependency("dvui", .{ .target = target, .optimize = optimize });
    exe.root_module.addImport("dvui", dvui.module("dvui_raylib"));
    exe_check.root_module.addImport("dvui", dvui.module("dvui_raylib"));
    exe_test.root_module.addImport("dvui", dvui.module("dvui_raylib"));

    //================ADD ZIGLUA====================
    const ziglua = b.dependency("ziglua", .{ .target = target, .optimize = optimize });
    exe.root_module.addImport("ziglua", ziglua.module("ziglua"));
    exe_check.root_module.addImport("ziglua", ziglua.module("ziglua"));
    exe_test.root_module.addImport("ziglua", ziglua.module("ziglua"));

    //===============DEFINE LUA TYPES=====================
    const exe_define = b.addExecutable(.{
        .name = "define",
        .root_source_file = b.path("src/define_exe.zig"),
        .target = target,
    });
    exe_define.root_module.addImport("ziglua", ziglua.module("ziglua"));

    var run_exe_define = b.addRunArtifact(exe_define);
    run_exe_define.addFileArg(b.path("data/lua/definitions.lua"));

    const define_step = b.step("define", "");
    define_step.dependOn(&run_exe_define.step);

    //===============LINT LUA===========================

    const lua_files_path = "data/lua";

    const lint_commands: []const []const u8 = &.{
        "lua-language-server",
        "--check",
        b.path(lua_files_path).getPath(b),
        "--logpath",
        "--checklevel=Hint",
        "--logpath",
        b.path(".zig-cache").getPath(b),
    };
    var lint = b.addSystemCommand(lint_commands);
    _ = &lint; // autofix

    // jq -r 'to_entries[] | .key as $file | .value[] | "\($file): \(.message) at line \(.range.start.line)"'

    //const log_commands: []const []const u8 = &.{
    //    "jq",
    //    "-r",
    //    //"\"to_entries[] | .key as $file | .value[] | \\\"\\($file): \\(.message) at line \\(.range.start.line)\\\"\"",
    //    \\"to_entries[] | .key as $file | .value[] | \"\($file): \(.message) at line \(.range.start.line)\""
    //    ,
    //    b.path(".zig-cache/check.json").getPath(b),
    //};
    //var log = b.addSystemCommand(log_commands);
    //log.step.dependOn(&lint.step);

    //var lint_step = b.step("lint", "lint lua");
    //lint_step.dependOn(&log.step);

    //================LINK RAYLIB===================
    const maybe_ray = dvui.builder.lazyDependency("raylib", .{ .target = target, .optimize = optimize });
    if (maybe_ray) |ray| {
        exe.linkLibrary(ray.artifact("raylib"));
        exe_check.linkLibrary(ray.artifact("raylib"));
        exe_test.linkLibrary(ray.artifact("raylib"));
        exe_define.linkLibrary(ray.artifact("raylib"));

        const glad_path = ray.path("src/external");
        exe.addIncludePath(glad_path);
        exe_test.addIncludePath(glad_path);
        exe_check.addIncludePath(glad_path);
        exe_define.addIncludePath(glad_path);

        const ray_path = ray.path("src");
        exe.addIncludePath(ray_path);
        exe_test.addIncludePath(ray_path);
        exe_check.addIncludePath(ray_path);
        exe_define.addIncludePath(ray_path);
    }

    const maybe_raygui = dvui.builder.lazyDependency("raygui", .{ .target = target, .optimize = optimize });
    if (maybe_raygui) |raygui| {
        const raygui_path = raygui.path("src");
        exe.addIncludePath(raygui_path);
        exe_test.addIncludePath(raygui_path);
        exe_check.addIncludePath(raygui_path);
        exe_define.addIncludePath(raygui_path);
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
