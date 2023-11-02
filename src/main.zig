const std = @import("std");
const cam = @import("camera.zig");
const anime = @import("animation.zig");
const tile = @import("tiles.zig");
const Arena = std.heap.ArenaAllocator;
const page_allocator = std.heap.page_allocator;
const level = @import("level.zig");
const file = @import("file_utils.zig");
const menu = @import("menu.zig");
const key = @import("keybindings.zig");
const save = @import("save.zig");
const err = @import("error.zig");
const texture = @import("textures.zig");
const options = @import("options.zig");
const ecs = @import("ecs.zig");
const sys = @import("systems.zig");
const animate = @import("animation.zig");
const debug = @import("debug.zig");

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

    var debug_mode = true;

    //const shader = ray.LoadShader(0, ray.TextFormat("game-files/shaders/grayscale.fs", @as(c_int, 330)));
    //defer ray.UnloadShader(shader);

    var camera = cam.initCamera();

    while (!ray.WindowShouldClose()) {

        //debug on or off
        if (keybindings.debug_mode.pressed()) {
            debug_mode = !debug_mode;
        }

        //configure update options
        const delta_time = ray.GetFrameTime();
        const update_options = options.Update{ .dt = delta_time };
        camera = cam.calculateCameraPosition(camera, lvl, &tile_state, &keybindings);

        try sys.updateMovementSystem(lvl.ecs, a, lvl.map, &animation_state, update_options);
        sys.updatePlayerSystem(lvl.ecs, a, keybindings, camera, tile_state.resolution, update_options);
        sys.updateWanderingSystem(lvl.ecs, a, update_options);
        try sys.updateDamageSystem(lvl.ecs, a, update_options);
        sys.updateHealthCooldownSystem(lvl.ecs, a, update_options);
        sys.updateDeathSystem(lvl.ecs, a, update_options);
        sys.updateSpriteSystem(lvl.ecs, a, &animation_state, update_options);

        ray.BeginDrawing();
        ray.BeginMode2D(camera); // Begin 2D mode with custom camera (2D)
        //        ray.BeginShaderMode(shader);

        ray.ClearBackground(ray.RAYWHITE);

        lvl.map.render(&animation_state, &tile_state);

        if (debug_mode) {
            debug.renderPositionCache(lvl.ecs, a, tile_state.resolution);
            debug.renderHitboxes(lvl.ecs, a, tile_state.resolution);
        }

        sys.renderSprites(lvl.ecs, a, &animation_state, &tile_state);

        //       ray.EndShaderMode();
        ray.EndMode2D();
        if (debug_mode) {
            ray.DrawFPS(15, 15);
            try debug.renderEntityCount(lvl.ecs);
        }
        ray.EndDrawing();

        if (ray.IsKeyPressed('Q')) {
            return .quit;
        }
    }
    return .quit;
}

test "unit tests" {
    @import("std").testing.refAllDecls(@This());
}
