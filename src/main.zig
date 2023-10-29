pub const std = @import("std");
const anime = @import("animation.zig");
pub const tile = @import("tiles.zig");
pub const Arena = std.heap.ArenaAllocator;
pub const page_allocator = std.heap.page_allocator;
pub const level = @import("level.zig");
pub const file = @import("file_utils.zig");
pub const menu = @import("menu.zig");
pub const key = @import("keybindings.zig");
pub const save = @import("save.zig");
pub const err = @import("error.zig");
pub const texture = @import("textures.zig");
pub const options = @import("options.zig");
pub const ecs = @import("ecs.zig");
pub const sys = @import("systems.zig");
pub const animate = @import("animation.zig");
//pub const toml = @import("toml");
const t2j = @cImport({
    @cInclude("toml-to-json.h");
});

const ray = @cImport({
    @cInclude("raylib.h");
});
const raygui = @cImport({
    @cInclude("raygui.h");
    @cInclude("style_dark.h");
});

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{ .verbose_log = true, .retain_metadata = true, .enable_memory_limit = true }){};
    defer _ = gpa.detectLeaks();
    //const a = gpa.allocator();
    var my_arena = Arena.init(gpa.allocator());
    defer my_arena.deinit();
    //var logger = std.heap.LoggingAllocator(std.log.Level.info, std.log.Level.warn).init(my_arena.allocator());
    //const a = logger.allocator();
    const a = my_arena.allocator();

    ray.SetConfigFlags(ray.FLAG_WINDOW_RESIZABLE);
    ray.SetConfigFlags(ray.FLAG_VSYNC_HINT);
    ray.InitWindow(800, 450, "ziggity");
    defer ray.CloseWindow();

    raygui.GuiLoadStyleDark();
    ray.SetTargetFPS(60);

    var current_window = menu.Window.main_menu;
    var save_id: []u8 = "";

    while (!ray.WindowShouldClose()) {
        std.debug.print("WINDOW: {s}\n", .{save_id});
        current_window = switch (current_window) {
            .quit => break,
            .main_menu => menu.drawMainMenu(),
            .save_menu => try menu.drawSaveSelectMenu(a, &save_id),
            .config_menu => err.crashToMainMenu("config_menu_not_implemented_yet"),
            .new_save => try menu.drawNewSaveMenu(a),
            .game => try runGame(a, save_id),
        };
    }
}

fn runGame(a: std.mem.Allocator, current_save: []const u8) !menu.Window {
    const manifest = try file.readManifest(a, current_save);
    defer manifest.deinit();

    std.debug.print("manifest contents in main: \n{}\n\n", .{manifest.value});

    var json_parsed_level = file.readLevel(a, current_save, manifest.value.active_level_id) catch |e| {
        std.debug.print("ERROR: Failed to load {s} due to {}\n", .{ manifest.value.active_level_id, e });
        return err.crashToMainMenu("failed to load selected save");
    };

    defer json_parsed_level.deinit();
    var lvl = json_parsed_level.value;

    const keybindings = try key.KeyBindings.init(a);
    defer keybindings.deinit(a);

    var tile_state = try tile.TileState.init(a);
    defer tile_state.deinit();

    var animation_state = try anime.AnimationState.init(a);
    defer animation_state.animations.deinit();

    //const shader = ray.LoadShader(0, ray.TextFormat("game-files/shaders/grayscale.fs", @as(c_int, 330)));
    //defer ray.UnloadShader(shader);

    while (!ray.WindowShouldClose()) {

        //configure update options
        const delta_time = ray.GetFrameTime();
        const update_options = options.Update{ .dt = delta_time };
        const render_options = options.Render{ .zoom = 1, .scale = 1, .grid_spacing = 32 };

        sys.updateMovementSystem(lvl.ecs, a, lvl.map, &animation_state, update_options);
        sys.updatePlayerSystem(lvl.ecs, a, keybindings, update_options);
        sys.updateWanderingSystem(lvl.ecs, a, update_options);
        sys.updateDeathSystem(lvl.ecs, a, update_options);
        sys.updateSpriteSystem(lvl.ecs, a, &animation_state, update_options);

        //player.updatePlayer(lvl.player_id, lvl.entities, update_options);
        //rendering settings
        //if (s.keybindings.zoom_in.pressed() and render_options.zoom < 1.3) render_options.zoom *= 1.01;
        //if (s.keybindings.zoom_out.pressed() and render_options.zoom > 0.7) render_options.zoom *= 0.99;

        var camera = try calculateCameraPosition(lvl, render_options);

        //render
        ray.BeginDrawing();
        ray.BeginMode2D(camera); // Begin 2D mode with custom camera (2D)
        //        ray.BeginShaderMode(shader);

        ray.ClearBackground(ray.RAYWHITE);

        lvl.map.render(&animation_state, render_options);
        sys.renderSprites(lvl.ecs, a, &animation_state, render_options);

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
fn calculateCameraPosition(l: level.Level, render_options: options.Render) !ray.Camera2D {
    const player_id = l.player_id;
    var player_position: ray.Vector2 = l.ecs.components.physics.get(player_id).?.pos;
    //    std.debug.print("player_position: {}\n", .{player_position});
    //player_position.x += 1;
    //player_position.y += 2;
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
    @import("std").testing.refAllDecls(@This());
}
