const std = @import("std");
const Arena = std.heap.ArenaAllocator;
const page_allocator = std.heap.page_allocator;
const gpa = std.heap.GeneralPurposeAllocator(.{}){};
const level = @import("level.zig");
const file = @import("file_utils.zig");
const menu = @import("menu.zig");
const str = @import("str_utils.zig");
const config = @import("config.zig");

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

    var current_window = menu.Window.main_menu;
    var save_id: []u8 = "";

    const assets = try level.Assets.init(a);
    const keys = try config.KeyBindings.init(a);
    _ = keys;
    _ = assets;

    while (!ray.WindowShouldClose()) {
        std.debug.print("WINDOW: {s}\n", .{save_id});
        current_window = switch (current_window) {
            .quit => break,
            .main_menu => menu.drawMainMenu(),
            .save_menu => try menu.drawSaveSelectMenu(a, &save_id),
            .config_menu => .config_menu,
            .new_save => try menu.drawNewSaveMenu(a),
            .game => try runGame(a, save_id),
        };
    }
}

fn runGame(a: std.mem.Allocator, current_save: []const u8) !menu.Window {
    const save = try file.readSaveState(a, current_save);
    const lvl = try file.readLevel(a, save.name, save.current_level);

    while (!ray.WindowShouldClose()) {
        try lvl.update(a, 1.0);
        ray.BeginDrawing();
        ray.ClearBackground(ray.RAYWHITE);
        ray.DrawText("Now playing game!", 190, 44, 20, ray.LIGHTGRAY);
        try lvl.render(1.0);
        ray.EndDrawing();

        if (ray.IsKeyPressed('Q')) {
            return .quit;
        }
    }
    return .quit;
}
