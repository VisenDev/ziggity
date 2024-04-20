const std = @import("std");
const light = @import("light.zig");
const shade = @import("shaders.zig");
const move = @import("movement.zig");
const ai = @import("ai.zig");
const inv = @import("inventory.zig");
const cam = @import("camera.zig");
const anime = @import("animation.zig");
const tile = @import("tiles.zig");
const Arena = std.heap.ArenaAllocator;
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
const cmd = @import("console.zig");
const Lua = @import("ziglua").Lua;
const api = @import("api.zig");
const play = @import("player.zig");

const ray = @cImport({
    @cInclude("raylib.h");
});

const raygui = @cImport({
    @cInclude("raygui.h");
    @cInclude("style_dark.h");
});

fn playSound() void {
    ray.InitAudioDevice();
    defer ray.CloseAudioDevice();
    const music = ray.LoadMusicStream("game-files/audio/LittleFugue.mp3");
    ray.SetMusicVolume(music, 0.3);
    defer ray.UnloadMusicStream(music);
    ray.PlayMusicStream(music);
    std.debug.assert(ray.IsMusicStreamPlaying(music));

    while (!ray.WindowShouldClose()) {
        ray.UpdateMusicStream(music);
        std.time.sleep(@intFromFloat((1.0 / 60.0) * std.time.ns_per_s));
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{ .verbose_log = true, .retain_metadata = true, .enable_memory_limit = true }){};
    defer _ = gpa.detectLeaks();
    var my_arena = Arena.init(gpa.allocator());
    defer my_arena.deinit();
    const a = my_arena.allocator();

    ray.SetConfigFlags(ray.FLAG_WINDOW_RESIZABLE);
    ray.SetConfigFlags(ray.FLAG_VSYNC_HINT);
    ray.InitWindow(800, 450, "ziggity");
    defer ray.CloseWindow();

    //const music_player = try std.Thread.spawn(.{}, playSound, .{});
    //defer music_player.detach();

    var lua = try api.initLuaApi(&a);
    defer lua.deinit();

    raygui.GuiLoadStyleDark();
    ray.SetTargetFPS(1000);

    var current_window = menu.Window.main_menu;
    var save_id: []u8 = "";

    while (!ray.WindowShouldClose()) {
        std.debug.print("WINDOW: {s}\n", .{save_id});
        current_window = switch (current_window) {
            .quit => break,
            .main_menu => menu.drawMainMenu(),
            .save_menu => try menu.drawSaveSelectMenu(a, &save_id),
            .config_menu => err.crashToMainMenu("config_menu_not_implemented_yet"),
            .new_save => try menu.drawNewSaveMenu(a, &lua),
            .game => try runGame(a, &lua, save_id),
        };
    }
}

fn runGame(a: std.mem.Allocator, lua: *Lua, current_save: []const u8) !menu.Window {
    const manifest = try file.readManifest(a, current_save);
    defer manifest.deinit();

    var json_parsed_level = file.readLevel(a, current_save, manifest.value.active_level_id) catch |e| {
        std.debug.print("ERROR: Failed to load {s} due to {}\n", .{ manifest.value.active_level_id, e });
        return err.crashToMainMenu("failed to load selected save");
    };

    defer json_parsed_level.deinit();
    var lvl = json_parsed_level.value;

    var keybindings = try key.KeyBindings.init(a, lua);
    defer keybindings.deinit();

    var tile_state = try tile.TileState.init(a, lua);
    defer tile_state.deinit();

    var animation_state = try anime.AnimationState.init(a, lua);
    defer animation_state.animations.deinit();

    var console = try cmd.Console.init(a);
    defer console.deinit();

    var debug_mode = false;

    var light_shader = try light.LightShader.init(a);
    defer light_shader.deinit(a);

    var camera = cam.initCamera();
    var update_options = options.Update{};

    var target = ray.LoadRenderTexture(ray.GetScreenWidth(), ray.GetScreenHeight());
    defer ray.UnloadRenderTexture(target);

    while (!ray.WindowShouldClose()) {
        if (target.texture.width != ray.GetScreenWidth() or target.texture.height != ray.GetScreenHeight()) {
            ray.UnloadRenderTexture(target);
            target = ray.LoadRenderTexture(ray.GetScreenWidth(), ray.GetScreenHeight());
        }

        //debug on or off
        if (keybindings.isPressed("debug_mode")) {
            debug_mode = !debug_mode;
        }

        if (console.isPlayerTyping()) {
            keybindings.mode = .insert;
        } else {
            keybindings.mode = .normal;
        }

        //configure update options
        update_options.update();
        camera = cam.calculateCameraPosition(camera, lvl, &keybindings);

        try move.updateEntitySeparationSystem(lvl.ecs, a, update_options);
        try move.updateMovementSystem(lvl.ecs, a, lvl.map, update_options);
        try play.updatePlayerSystem(lvl.ecs, a, lua, keybindings, camera, update_options);
        try inv.updateInventorySystem(lvl.ecs, a, update_options);
        try sys.updateDeathSystem(lvl.ecs, a, lua, update_options);
        sys.updateHealthCooldownSystem(lvl.ecs, a, update_options);
        try sys.updateDamageSystem(lvl.ecs, a, update_options);
        sys.updateSpriteSystem(lvl.ecs, a, &animation_state, update_options);
        try sys.trimAnimationEntitySystem(lvl.ecs, a, update_options);
        try ai.updateControllerSystem(lvl.ecs, a, update_options);

        ray.BeginTextureMode(target);
        {
            ray.BeginMode2D(camera); // Begin 2D mode with custom camera (2D)
            ray.ClearBackground(ray.RAYWHITE);

            lvl.map.render(&animation_state, &tile_state);

            if (debug_mode) {
                try debug.renderWanderDestinations(lvl.ecs, a);
            }

            anime.renderSprites(lvl.ecs, a, &animation_state);

            for (0..10) |_| {
                try light_shader.addLight(a, .{
                    .color = .{ .x = 1.0, .y = 0.5, .z = 1.0, .a = 1.0 },
                    .radius = 100.0,
                    .position = .{ .x = 100, .y = 100 },
                }, camera);
            }

            light_shader.render();
        }
        ray.EndTextureMode();

        ray.BeginDrawing();
        {
            //ray.BeginMode2D(camera);
            ray.ClearBackground(ray.RAYWHITE); // Clear screen background

            // Enable shader using the custom uniform
            ray.BeginShaderMode(light_shader.shader);
            // NOTE: Render texture must be y-flipped due to default OpenGL coordinates (left-bottom)
            ray.DrawTextureRec(
                target.texture,
                .{
                    .x = 0,
                    .y = 0,
                    .width = @floatFromInt(target.texture.width),
                    .height = @floatFromInt(-target.texture.height),
                },
                .{ .x = 0, .y = 0 },
                ray.WHITE,
            );
            ray.EndShaderMode();

            // Draw some 2d text over drawn texture
            ray.DrawFPS(15, 15);
            try debug.renderEntityCount(lvl.ecs);
            inv.renderPlayerInventory(lvl.ecs, a, &animation_state);
        }
        ray.EndDrawing();

        if (ray.IsKeyPressed('Q')) {
            return .quit;
        }
    }
    return .quit;
}

test "unit tests" {
    @import("std").testing.refAllDeclsRecursive(@This());
}
