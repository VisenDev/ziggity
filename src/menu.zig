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

pub const Window = enum { main_menu, game, save_menu, config_menu, quit, new_save };

fn backgroundColor() ray.Color {
    return ray.GetColor(@intCast(ray.GuiGetStyle(0, ray.BACKGROUND_COLOR)));
}

pub fn drawMainMenu() Window {
    while (!ray.WindowShouldClose()) {
        ray.BeginDrawing();

        ray.ClearBackground(backgroundColor());
        ray.DrawText("Hello, World!", 190, 200, 20, ray.LIGHTGRAY);
        if (ray.GuiButton(ray.Rectangle{ .x = 20.0, .y = 20.0, .width = 115.0, .height = 30.0 }, "PLAY") == 1) {
            return .save_menu;
        }
        if (ray.GuiButton(ray.Rectangle{ .x = 20.0, .y = 60.0, .width = 115.0, .height = 30.0 }, "CONFIG") == 1) {
            return .config_menu;
        }
        if (ray.GuiButton(ray.Rectangle{ .x = 20.0, .y = 100.0, .width = 115.0, .height = 30.0 }, "QUIT") == 1) {
            return .quit;
        }

        ray.EndDrawing();
    }
    return .quit;
}

pub fn drawSaveSelectMenu(a: std.mem.Allocator, save_id: *[]u8) !Window {
    const path = try file.getSaveDirPath(a);
    const save_dir = std.fs.openDirAbsolute(path, .{ .iterate = true }) catch |e| switch (e) {
        error.FileNotFound => blk: {
            try std.fs.makeDirAbsolute(path);
            break :blk try std.fs.openDirAbsolute(path, .{ .iterate = true });
        },
        else => return e,
    };
    var i: f32 = 0;

    ray.SetMousePosition(0, 0);
    while (!ray.WindowShouldClose()) {
        ray.BeginDrawing();
        ray.ClearBackground(backgroundColor());

        var iterator = save_dir.iterate();
        while (try iterator.next()) |val| : (i += 1) {
            if (ray.GuiButton(ray.Rectangle{ .x = 20, .y = 60.0 + 40.0 * i, .width = 115.0, .height = 30.0 }, val.name.ptr) == 1) {
                save_id.* = try a.dupe(u8, val.name);
                return .game;
            }
        }

        if (ray.GuiButton(ray.Rectangle{ .x = 200.0, .y = 20.0, .width = 115.0, .height = 30.0 }, "Create new") == 1) {
            return .new_save;
        }

        ray.DrawText("Select a save!", 20, 20, 20, ray.DARKGRAY);
        ray.EndDrawing();
        i = 0;
    }
    return .quit;
}

pub fn drawNewSaveMenu(a: std.mem.Allocator, lua: *Lua) !Window {
    var levelNameEditMode = false;
    var levelNameText: [100]u8 = [_]u8{0} ** 100;

    var seedEditMode = false;
    var seedText: [100]u8 = [_]u8{0} ** 100;

    while (!ray.WindowShouldClose()) {
        ray.BeginDrawing();
        ray.ClearBackground(backgroundColor());

        ray.DrawText("Enter Save Name!", 140, 60, 20, ray.DARKGRAY);

        ray.GuiSetStyle(ray.TEXTBOX, ray.TEXT_ALIGNMENT, ray.TEXT_ALIGN_LEFT);
        if (ray.GuiTextBox(ray.Rectangle{ .x = 20.0, .y = 60.0, .width = 115.0, .height = 30.0 }, &levelNameText, 32, levelNameEditMode) == 1) {
            levelNameEditMode = !levelNameEditMode;
        }

        ray.DrawText("Enter Seed!", 140, 100, 20, ray.DARKGRAY);
        if (ray.GuiTextBox(ray.Rectangle{ .x = 20.0, .y = 100.0, .width = 115.0, .height = 30.0 }, &seedText, 32, seedEditMode) == 1) {
            seedEditMode = !seedEditMode;
        }

        if (ray.GuiButton(ray.Rectangle{ .x = 20.0, .y = 140.0, .width = 115.0, .height = 30.0 }, "Generate") == 1) {
            try level.createNewSave(a, lua, .{
                .save_id = levelNameText[0..std.mem.indexOf(u8, &levelNameText, &.{0}).?],
                .seed = try std.fmt.parseInt(usize, seedText[0..std.mem.indexOf(u8, &seedText, &.{0}).?], 10),
            });
            return .save_menu;
        }

        ray.EndDrawing();
    }

    return .quit;
}
