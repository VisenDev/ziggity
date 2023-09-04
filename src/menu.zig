const std = @import("std");
const file = @import("file_utils.zig");
const ray = @cImport({
    @cInclude("raylib.h");
    @cInclude("raygui.h");
    @cInclude("style_dark.h");
});

pub const Window = enum { main_menu, game, save_menu, config_menu, quit };

pub fn drawMainMenu() Window {
    while (true) {
        ray.BeginDrawing();

        ray.ClearBackground(ray.RAYWHITE);
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
}

pub fn drawSaveMenu(a: std.mem.Allocator) !Window {
    const path = try file.getSaveDirPath(a);
    const save_dir = try std.fs.openIterableDirAbsolute(path, .{});
    var i: f32 = 0;

    while (true) {
        ray.BeginDrawing();
        ray.ClearBackground(ray.RAYWHITE);

        var iterator = save_dir.iterate();
        while (try iterator.next()) |val| : (i += 1) {
            if (ray.GuiButton(ray.Rectangle{ .x = 20, .y = 60.0 + 40.0 * i, .width = 115.0, .height = 30.0 }, val.name.ptr) == 1) {
                return .game;
            }
        }

        ray.DrawText("Select a save!", 20, 20, 20, ray.DARKGRAY);
        ray.EndDrawing();
        i = 0;
    }
}
