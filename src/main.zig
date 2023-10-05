const std = @import("std");
const Arena = std.heap.ArenaAllocator;
const page_allocator = std.heap.page_allocator;
const level = @import("level.zig");
const file = @import("file_utils.zig");
const menu = @import("menu.zig");
const config = @import("config.zig");
const save = @import("save.zig");
const err = @import("error.zig");
const player = @import("player.zig");
const texture = @import("textures.zig");
const toml = @import("toml");

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
    ray.SetTargetFPS(180);

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
    var s = save.Save.load(a, current_save) catch return err.crashToMainMenu("failed to load selected save");
    try s.level.entities.audit();
    defer s.deinit(a);

    //const grid_spacing: u32 = 32;
    var render_options = texture.RenderOptions{ .scale = 4.0, .grid_spacing = 32, .zoom = 1 };

    const palette = [_]u32{ // RKBV (2-strip film
        4,   12,  6,
        17,  35,  24,
        30,  58,  41,
        48,  93,  66,
        77,  128, 97,
        137, 162, 87,
        190, 220, 127,
        238, 255, 204,
    };
    _ = palette;
    const shader = ray.LoadShader(0, ray.TextFormat("game-files/shaders/grayscale.fs", @as(c_int, 330)));
    defer ray.UnloadShader(shader);

    while (!ray.WindowShouldClose()) {

        //update scene
        const delta_time = ray.GetFrameTime();
        try s.level.update(a, level.UpdateOptions{ .keys = &s.keybindings, .dt = delta_time });

        //rendering settings
        if (s.keybindings.zoom_in.pressed() and render_options.zoom < 1.3) render_options.zoom *= 1.01;
        if (s.keybindings.zoom_out.pressed() and render_options.zoom > 0.7) render_options.zoom *= 0.99;
        var camera = try calculateCameraPosition(s.level, render_options);

        //render
        ray.BeginDrawing();
        ray.BeginMode2D(camera); // Begin 2D mode with custom camera (2D)
        //        ray.BeginShaderMode(shader);

        ray.ClearBackground(ray.RAYWHITE);
        try s.level.render(assets, render_options);

        //       ray.EndShaderMode();
        ray.EndMode2D();
        ray.DrawFPS(15, 15);
        ray.EndDrawing();

        if (ray.IsKeyPressed('Q')) {
            return .quit;
        }
    }
    return .quit;
}

fn screenWidth() f32 {
    return @floatFromInt(ray.GetScreenWidth());
}

fn screenHeight() f32 {
    return @floatFromInt(ray.GetScreenHeight());
}

fn tof32(input: anytype) f32 {
    return @floatFromInt(input);
}

//TODO update camera offset
fn calculateCameraPosition(l: level.Level, render_options: texture.RenderOptions) !ray.Camera2D {
    var player_position = try l.getPlayerPosition();
    player_position.x += 1;
    player_position.y += 2;
    player_position.x *= render_options.grid_spacing;
    player_position.y *= render_options.grid_spacing;

    const min_camera_x: f32 = (screenWidth() / 2) / render_options.zoom;
    const min_camera_y: f32 = (screenHeight() / 2) / render_options.zoom;

    if (player_position.x < min_camera_x) {
        player_position.x = min_camera_x;
    }

    if (player_position.y < min_camera_y) {
        player_position.y = min_camera_y;
    }

    const map_width: f32 = (tof32(l.map.width)) * render_options.grid_spacing;
    const map_height: f32 = (tof32(l.map.height)) * render_options.grid_spacing;
    const max_camera_x: f32 = map_width - min_camera_x;
    const max_camera_y: f32 = map_height - min_camera_y;

    if (player_position.x > max_camera_x) {
        player_position.x = max_camera_x;
    }

    if (player_position.y > max_camera_y) {
        player_position.y = max_camera_y;
    }

    return ray.Camera2D{
        .offset = .{ .x = screenWidth() / 2, .y = screenHeight() / 2 },
        .rotation = 0.0,
        .zoom = render_options.zoom,
        .target = player_position,
    };
}

test "unit tests" {
    _ = @This();
}
