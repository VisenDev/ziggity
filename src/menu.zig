const std = @import("std");
const Lua = @import("ziglua").Lua;
const file = @import("file_utils.zig");
const save = @import("save.zig");
const level = @import("level.zig");
const ray = @cImport({
    @cInclude("raylib.h");
});

const raygui = @cImport({
    @cInclude("raygui.h");
});

const gui = @import("gui.zig");

pub const Window = enum { main_menu, game, save_menu, config_menu, quit, new_save };

fn backgroundColor() ray.Color {
    return ray.GetColor(@intCast(ray.GuiGetStyle(ray.DEFAULT, ray.BACKGROUND_COLOR)));
}

pub fn drawMainMenu(a: std.mem.Allocator) !Window {
    var gui_manager = gui.RayGuiManager.init(a);
    defer gui_manager.deinit();

    gui.styles.GuiLoadStyleJungle();

    while (!ray.WindowShouldClose()) {
        gui_manager.update();
        ray.BeginDrawing();

        ray.ClearBackground(gui_manager.backgroundColor());
        //gui_manager.panel(null);
        if (gui_manager.button("PLAY")) return .save_menu;
        if (gui_manager.button("CONFIG")) return .config_menu;
        if (gui_manager.button("QUIT")) return .quit;
        gui_manager.column();
        try gui_manager.guiStylePicker();
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
    const files = try listFiles(a, save_dir);
    defer {
        for (files.items) |item| {
            a.free(item);
        }
        files.deinit();
    }

    var selected_file_index: ?usize = null;

    while (!ray.WindowShouldClose()) {
        gui_manager.update();
        ray.BeginDrawing();
        ray.ClearBackground(gui_manager.backgroundColor());

        if (gui_manager.button("Create New")) {
            return .new_save;
        }

        if (gui_manager.button("Return To Main Menu")) {
            return .main_menu;
        }

        gui_manager.column();

        try gui_manager.startScrollPanel("saves list", 6, @floatFromInt(files.items.len));
        for (files.items, 0..) |filename, i| {
            if (gui_manager.button(filename)) {
                selected_file_index = i;
            }
        }
        gui_manager.endScrollPanel();

        gui_manager.column();

        if (selected_file_index) |i| {
            gui_manager.title(files.items[i]);
            if (gui_manager.button("open")) {
                save_id.* = try a.dupeZ(u8, files.items[i]);
                return .game;
            }
            gui_manager.line();
            if (gui_manager.button("close")) {
                selected_file_index = null;
            }
            gui_manager.column();
        }

        ray.EndDrawing();
    }

    return .quit;
}

pub fn drawNewSaveMenu(a: std.mem.Allocator, lua: *Lua) !Window {
    var save_name: [:0]const u8 = undefined;
    var seed: usize = 123321;
    var gui_manager = gui.RayGuiManager.init(a);
    defer gui_manager.deinit();

    while (!ray.WindowShouldClose()) {
        gui_manager.update();
        ray.BeginDrawing();
        ray.ClearBackground(gui_manager.backgroundColor());

        save_name = try gui_manager.textBox("Save Name");
        seed = try gui_manager.valueBox(usize, "Numeric Seed");

        if (gui_manager.button("Generate")) {
            try level.createNewSave(a, lua, .{
                .save_id = save_name,
                .seed = @intCast(@abs(seed)),
            });
            return .save_menu;
        }

        ray.EndDrawing();
    }

    return .quit;
}
