const std = @import("std");

const menu = @import("menu.zig");
const ray = @cImport({
    @cInclude("raylib.h");
    @cInclude("raygui.h");
});

///shows error message then returns
pub fn crashToMainMenu(err: []const u8) menu.Window {
    while (true) {
        ray.BeginDrawing();
        ray.ClearBackground(ray.RAYWHITE);
        ray.DrawText("ERROR", 20, 20, 20, ray.BLACK);
        ray.DrawText(err.ptr, 20, 60, 20, ray.BLACK);

        if (ray.GuiButton(ray.Rectangle{ .x = 20, .y = 120.0, .width = @as(f32, @floatFromInt(err.len)) * 10.0, .height = 30.0 }, "Return to Main Menu") == 1) {
            return .main_menu;
        }

        ray.EndDrawing();
    }
}

///Brings up a crash menu showing the error message
pub fn crash(err: []const u8) noreturn {
    while (true) {
        ray.BeginDrawing();
        ray.ClearBackground(ray.BLUE);
        ray.DrawText("FATAL ERROR", 20, 20, 20, ray.RAYWHITE);
        ray.DrawText(err.ptr, 20, 60, 20, ray.RAYWHITE);

        if (ray.GuiButton(ray.Rectangle{ .x = 20, .y = 120.0, .width = @as(f32, @floatFromInt(err.len)) * 10.0, .height = 30.0 }, "OK") == 1) {
            @panic(err);
        }

        ray.EndDrawing();
    }
}
