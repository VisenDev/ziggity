const std = @import("std");
const Arena = std.heap.ArenaAllocator;
const page_allocator = std.heap.page_allocator;
const level = @import("level.zig");
const file = @import("file_utils.zig");
const menu = @import("menu.zig");
const str = @import("str_utils.zig");
const config = @import("config.zig");
const save = @import("save.zig");
const err = @import("error.zig");
const player = @import("player.zig");

const ray = @cImport({
    @cInclude("raylib.h");
});
const raygui = @cImport({
    @cInclude("raygui.h");
    @cInclude("style_dark.h");
});

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.detectLeaks();
    var my_arena = Arena.init(gpa.allocator());
    defer my_arena.deinit();
    const a = my_arena.allocator();

    ray.SetConfigFlags(ray.FLAG_WINDOW_RESIZABLE);
    ray.SetConfigFlags(ray.FLAG_VSYNC_HINT);
    ray.InitWindow(800, 450, "ziggity");
    defer ray.CloseWindow();

    raygui.GuiLoadStyleDark();
    ray.SetTargetFPS(60);

    var current_window = menu.Window.main_menu;
    var save_id: []u8 = "";
    const assets = try level.Assets.init(a);
    defer assets.deinit(a); //unloads all textures from gpu

    while (!ray.WindowShouldClose()) {
        std.debug.print("WINDOW: {s}\n", .{save_id});
        current_window = switch (current_window) {
            .quit => break,
            .main_menu => menu.drawMainMenu(),
            .save_menu => try menu.drawSaveSelectMenu(a, &save_id),
            .config_menu => err.crashToMainMenu("config_menu_not_implemented_yet"),
            .new_save => try menu.drawNewSaveMenu(a, assets),
            .game => try runGame(a, assets, save_id),
        };
    }
}

fn runGame(a: std.mem.Allocator, assets: level.Assets, current_save: []const u8) !menu.Window {
    var s = try save.Save.load(a, current_save);
    try s.level.entities.audit();
    defer s.deinit(a);

    var camera = ray.Camera2D{
        .offset = .{ .x = @as(f32, @floatFromInt(ray.GetScreenWidth())) / 2, .y = @as(f32, @floatFromInt(ray.GetScreenHeight())) / 2 },
        .rotation = 0.0,
        .zoom = 1.0,
        .target = .{ .x = 0, .y = 0 },
    };

    ray.BeginMode2D(camera); // Begin 2D mode with custom camera (2D)
    const texture_id = assets.texture_state.name_index.get("slime").?;
    _ = try s.level.entities.spawnEntity(a, .{
        .position = .{},
        .renderer = .{ .texture_id = texture_id },
    });
    try s.level.entities.audit();

    const grid_spacing: u32 = 32;

    while (!ray.WindowShouldClose()) {
        //update scene
        const delta_time = ray.GetFrameTime();
        try s.level.update(a, &s.keybindings, delta_time);

        //update camera
        {
            var player_position = (try s.level.entities.systems.position.get(s.level.player_id)).?.pos;
            const min_camera_x = @as(f32, @floatFromInt(ray.GetScreenWidth())) / 2.0 - grid_spacing;
            const min_camera_y = @as(f32, @floatFromInt(ray.GetScreenHeight())) / 2.0 - grid_spacing;
            if (player_position.x < min_camera_x) {
                player_position.x = min_camera_x;
            }

            if (player_position.y < min_camera_y) {
                player_position.y = min_camera_y;
            }

            const map_width: f32 = @as(f32, @floatFromInt(s.level.map.width)) * grid_spacing;
            const map_height: f32 = @as(f32, @floatFromInt(s.level.map.height)) * grid_spacing;
            const max_camera_x: f32 = map_width - min_camera_x;
            const max_camera_y: f32 = map_height - min_camera_y;

            if (player_position.x > max_camera_x) {
                player_position.x = max_camera_x;
            }

            if (player_position.y > max_camera_y) {
                player_position.y = max_camera_y;
            }

            camera.target = player_position;
        }

        //render
        ray.BeginDrawing();
        ray.BeginMode2D(camera); // Begin 2D mode with custom camera (2D)

        ray.ClearBackground(ray.RAYWHITE);
        ray.DrawText("Now playing game!", 190, 44, 20, ray.LIGHTGRAY);
        try s.level.render(assets, .{ .scale = 4.0, .grid_spacing = grid_spacing });

        ray.EndMode2D();
        ray.EndDrawing();

        if (ray.IsKeyPressed('Q')) {
            return .quit;
        }
    }
    return .quit;
}
