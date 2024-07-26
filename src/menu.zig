const std = @import("std");
const Lua = @import("ziglua").Lua;
const file = @import("file_utils.zig");
const save = @import("save.zig");
const level = @import("level.zig");
const ray = @cImport({
    @cInclude("raylib.h");
    @cInclude("raygui.h");
    @cInclude("style_dark.h");
});

const gui = @import("gui.zig");

pub const Window = enum { main_menu, game, save_menu, config_menu, quit, new_save };

fn backgroundColor() ray.Color {
    return ray.GetColor(@intCast(ray.GuiGetStyle(0, ray.BACKGROUND_COLOR)));
}

pub fn drawMainMenu(a: std.mem.Allocator) Window {
    var gui_manager = gui.RayGuiManager.init(a);
    defer gui_manager.deinit();

    while (!ray.WindowShouldClose()) {
        gui_manager.update();
        ray.BeginDrawing();

        ray.ClearBackground(backgroundColor());
        if (gui_manager.button("PLAY")) return .save_menu;
        if (gui_manager.button("CONFIG")) return .config_menu;
        if (gui_manager.button("QUIT")) return .quit;
        ray.EndDrawing();
    }
    return .quit;
}

pub fn listFiles(a: std.mem.Allocator, dir: std.fs.Dir) !std.ArrayList([:0]const u8) {
    var iterator = dir.iterate();
    var result = std.ArrayList([:0]const u8).init(a);

    while (try iterator.next()) |entry| {
        try result.append(try a.dupeZ(u8, entry.name));
    }

    std.sort.pdq([:0]const u8, result.items, {}, struct {
        fn lt(_: void, l: [:0]const u8, r: [:0]const u8) bool {
            return std.ascii.lessThanIgnoreCase(l, r);
        }
    }.lt);

    return result;
}

pub fn drawSaveSelectMenu(a: std.mem.Allocator, save_id: *[]u8) !Window {
    var gui_manager = gui.RayGuiManager.init(a);
    defer gui_manager.deinit();

    const path = try file.getSaveDirPath(a);
    const save_dir = std.fs.openDirAbsolute(path, .{ .iterate = true }) catch |e| switch (e) {
        error.FileNotFound => blk: {
            try std.fs.makeDirAbsolute(path);
            break :blk try std.fs.openDirAbsolute(path, .{ .iterate = true });
        },
        else => return e,
    };
    ray.SetMousePosition(0, 0);

    const files = try listFiles(a, save_dir);
    defer {
        for (files.items) |item| {
            a.free(item);
        }
        files.deinit();
    }

    while (!ray.WindowShouldClose()) {
        gui_manager.update();
        ray.BeginDrawing();
        ray.ClearBackground(backgroundColor());

        if (gui_manager.button("Create New")) {
            return .new_save;
        }
        gui_manager.line();

        for (files.items) |filename| {
            if (gui_manager.button(filename)) {
                save_id.* = try a.dupeZ(u8, filename);
                return .game;
            }
        }

        ray.EndDrawing();
    }

    return .quit;
}

pub fn drawNewSaveMenu(a: std.mem.Allocator, lua: *Lua) !Window {
    var save_name: [:0]const u8 = undefined;
    var seed: [:0]const u8 = undefined;
    var gui_manager = gui.RayGuiManager.init(a);
    defer gui_manager.deinit();

    while (!ray.WindowShouldClose()) {
        gui_manager.update();
        ray.BeginDrawing();
        ray.ClearBackground(backgroundColor());

        save_name = try gui_manager.textBox("Save Name");
        seed = try gui_manager.textBox("Numeric Seed");

        if (gui_manager.button("Generate")) {
            try level.createNewSave(a, lua, .{
                .save_id = save_name,
                .seed = try std.fmt.parseInt(usize, seed, 10),
            });
            return .save_menu;
        }

        ray.EndDrawing();
    }

    return .quit;
}
