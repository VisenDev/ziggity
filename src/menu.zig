const std = @import("std");
const file = @import("file_utils.zig");
const save = @import("save.zig");
const level = @import("level.zig");
const ray = @cImport({
    @cInclude("raylib.h");
    @cInclude("raygui.h");
    @cInclude("style_dark.h");
});

pub const Window = enum { main_menu, game, save_menu, config_menu, quit, new_save };

pub fn drawMainMenu() Window {
    while (!ray.WindowShouldClose()) {
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
    return .quit;
}

pub fn drawSaveSelectMenu(a: std.mem.Allocator, save_id: *[]u8) !Window {
    const path = try file.getSaveDirPath(a);
    const save_dir = try std.fs.openIterableDirAbsolute(path, .{});
    var i: f32 = 0;

    ray.SetMousePosition(0, 0);
    while (!ray.WindowShouldClose()) {
        ray.BeginDrawing();
        ray.ClearBackground(ray.RAYWHITE);

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

pub fn drawNewSaveMenu(a: std.mem.Allocator, assets: level.Assets) !Window {
    var textBoxEditMode = false;
    var textBoxText: [100]u8 = [_]u8{0} ** 100;

    while (!ray.WindowShouldClose()) {
        ray.BeginDrawing();
        ray.ClearBackground(ray.RAYWHITE);

        ray.DrawText("Enter Save Name!", 20, 20, 20, ray.DARKGRAY);

        ray.GuiSetStyle(ray.TEXTBOX, ray.TEXT_ALIGNMENT, ray.TEXT_ALIGN_LEFT);
        if (ray.GuiTextBox(ray.Rectangle{ .x = 20.0, .y = 60.0, .width = 115.0, .height = 30.0 }, &textBoxText, 32, textBoxEditMode) == 1) {
            textBoxEditMode = !textBoxEditMode;
        }

        if (ray.GuiButton(ray.Rectangle{ .x = 20.0, .y = 100.0, .width = 115.0, .height = 30.0 }, "Generate") == 1) {
            var strlen: usize = 0;
            for (textBoxText, 0..) |ch, i| {
                if (ch == 0) {
                    strlen = i;
                    break;
                }
            }

            try save.Save.create(a, assets, .{ .name = textBoxText[0..strlen] });
            return .save_menu;
        }

        ray.EndDrawing();
    }

    return .quit;
}
