const std = @import("std");
const entity = @import("entity.zig");
const Arena = std.heap.ArenaAllocator;
const page_allocator = std.heap.page_allocator;
const gpa = std.heap.GeneralPurposeAllocator(.{}){};
const level = @import("level.zig");
const file = @import("file_utils.zig");
const menu = @import("menu.zig");

const ray = @cImport({
    @cInclude("raylib.h");
    @cInclude("raygui.h");
    @cInclude("style_dark.h");
});

pub fn main() !void {
    var my_arena = Arena.init(page_allocator);
    defer my_arena.deinit();
    const a = my_arena.allocator();

    ray.InitWindow(800, 450, "raylib [core] example - basic window");
    defer ray.CloseWindow();

    ray.GuiLoadStyleDark();
    ray.SetTargetFPS(60);
    //const saves = try menu.getSaveIDs(a);

    var current_window = menu.Window.main_menu;

    while (!ray.WindowShouldClose()) {
        current_window = switch (current_window) {
            .quit => break,
            .main_menu => menu.drawMainMenu(),
            .save_menu => try menu.drawSaveMenu(a),
            .config_menu => .config_menu,
            .game => while (true) {
                ray.BeginDrawing();
                ray.ClearBackground(ray.RAYWHITE);
                ray.DrawText("Now playing game!", 190, 44, 20, ray.LIGHTGRAY);
                ray.EndDrawing();

                if (ray.IsKeyPressed('Q')) {
                    break .quit;
                }
            },
        };
    }
}
