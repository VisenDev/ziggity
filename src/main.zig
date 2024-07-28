const std = @import("std");
const Component = @import("components.zig");
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
});

const gl = @cImport({
    @cInclude("glad.h");
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
    var gpa = std.heap.GeneralPurposeAllocator(.{ .retain_metadata = true, .enable_memory_limit = true }){};
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

    //raygui.GuiLoadStyleDark();
    ray.SetTargetFPS(200);

    var current_window = menu.Window.main_menu;
    var save_id: []u8 = "";

    while (!ray.WindowShouldClose()) {
        std.debug.print("WINDOW: {s}\n", .{save_id});
        current_window = switch (current_window) {
            .quit => break,
            .main_menu => try menu.drawMainMenu(a),
            .save_menu => try menu.drawSaveSelectMenu(a, &save_id),
            .config_menu => err.crashToMainMenu("config_menu_not_implemented_yet"),
            .new_save => try menu.drawNewSaveMenu(a, lua),
            .game => try runGame(a, lua, save_id),
        };
    }
}

fn runGame(a: std.mem.Allocator, lua: *Lua, current_save: []const u8) !menu.Window {
    const manifest = try file.readManifest(a, current_save);
    defer manifest.deinit();

    var json_parsed_level = level.Level.read(a, current_save, manifest.value.active_level_id) catch |e| {
        std.debug.print("ERROR: Failed to load {s} due to {}\n", .{ manifest.value.active_level_id, e });
        return err.crashToMainMenu("failed to load selected save");
    };

    defer json_parsed_level.deinit();
    var lvl = json_parsed_level.value;

    var tile_state = try tile.TileState.init(a, lua);
    defer tile_state.deinit();

    var window_manager = try anime.WindowManager.init(a, lua);
    defer window_manager.animations.deinit();

    var light_shader = try light.LightShader.init(a);
    defer light_shader.deinit(a);

    var target = ray.LoadRenderTexture(ray.GetScreenWidth(), ray.GetScreenHeight());
    defer ray.UnloadRenderTexture(target);

    var bloom_layer = ray.LoadRenderTexture(ray.GetScreenWidth(), ray.GetScreenHeight());
    defer ray.UnloadRenderTexture(bloom_layer);

    //const bloom_shader = try shade.loadFragmentShader(a, "blur.fs");
    //defer ray.UnloadShader(bloom_shader);
    var bloom_shader = try shade.FragShader.init(a, "blur.fs");
    defer bloom_shader.deinit();

    var debugger = try debug.DebugRenderer.init(a);
    defer debugger.deinit();

    var update_options = options.Update{ .debugger = &debugger };

    //temporary variable, TODO add this functionality to window manager
    var bloom_shaders = true;
    var light_shaders = true;

    while (!ray.WindowShouldClose()) {

        //reload render textures on window size change
        if (target.texture.width != ray.GetScreenWidth() or target.texture.height != ray.GetScreenHeight()) {
            ray.UnloadRenderTexture(target);
            target = ray.LoadRenderTexture(ray.GetScreenWidth(), ray.GetScreenHeight());
        }

        if (bloom_layer.texture.width != ray.GetScreenWidth() or bloom_layer.texture.height != ray.GetScreenHeight()) {
            ray.UnloadRenderTexture(bloom_layer);
            bloom_layer = ray.LoadRenderTexture(ray.GetScreenWidth(), ray.GetScreenHeight());
        }

        //debug on or off
        if (window_manager.keybindings.isPressed("debug_mode")) {
            debugger.enabled = !debugger.enabled;
        }

        //configure update options
        window_manager.updateCameraPosition(a, lvl);
        update_options.update();

        //reset mouse layers
        window_manager.resetMouseOwner();

        debugger.addText("FPS: {}", .{ray.GetFPS()});
        debugger.addText("Entity Count: {}", .{lvl.ecs.getNumEntities()});
        if (debugger.addTextButton(&window_manager, "[Toggle Light Shaders]", .{})) light_shaders = !light_shaders;
        if (debugger.addTextButton(&window_manager, "[Toggle Bloom Shaders]", .{})) bloom_shaders = !bloom_shaders;
        if (debugger.addTextButton(&window_manager, "[Save]", .{})) try lvl.save(a);
        if (debugger.addTextButton(&window_manager, "[Main Menu]", .{})) return .main_menu;

        try move.updateEntitySeparationSystem(lvl.ecs, a, lvl.map, update_options);
        try move.updateMovementSystem(lvl.ecs, a, lvl.map, update_options);
        try move.updatePositionCacheSystem(lvl.ecs, a, lvl.map, update_options);
        try inv.updateInventorySystem(lvl.ecs, a, &window_manager, lvl.map, update_options);
        try play.updatePlayerSystem(lvl.ecs, a, lua, &window_manager, update_options);
        try inv.updateItemSystem(lvl.ecs, a, &window_manager, update_options);
        try sys.updateLifetimeSystem(lvl.ecs, a, update_options);
        try sys.updateDeathSystem(lvl.ecs, a, lua, update_options);
        sys.updateHealthCooldownSystem(lvl.ecs, a, update_options);
        try sys.updateDamageSystem(lvl.ecs, a, lvl.map, update_options);
        sys.updateSpriteSystem(lvl.ecs, a, &window_manager, update_options);
        try sys.trimAnimationEntitySystem(lvl.ecs, a, update_options);
        try ai.updateControllerSystem(lvl.ecs, a, update_options);
        try light.updateLightingSystem(lvl.ecs, a, &light_shader, update_options);

        ray.BeginTextureMode(target);
        {
            ray.BeginMode2D(window_manager.camera); // Begin 2D mode with custom camera (2D)
            ray.ClearBackground(ray.BLACK);

            lvl.map.renderMain(a, &window_manager, lvl.ecs);
            lvl.map.renderBorders(a, &window_manager, lvl.ecs);

            //gl.glEnable(gl.GL_STENCIL_TEST);

            inv.renderItems(lvl.ecs, a, &window_manager);
            anime.renderSprites(lvl.ecs, a, &window_manager, update_options);

            try light_shader.render(&window_manager);
            ray.EndMode2D();
        }
        ray.EndTextureMode();

        //try light_shader.shader.setShaderValue("texture1", ray.Texture2D, &target.texture);
        //ray.BeginShaderMode(light_shader.shader.raw_shader); // Enable our custom shader for next shapes/textures drawings
        //ray.DrawTexture(bloom_layer.texture, 0, 0, ray.WHITE); // Drawing BLANK texture, all magic happens on shader
        //ray.EndShaderMode(); // Disable our custom shader, return to default shader
        const value: f32 = 0.005;
        try bloom_shader.setShaderValue("blur_size", f32, &value);

        //ray.BeginTextureMode(bloom_layer);
        //{
        //    ray.BeginMode2D(window_manager.camera); // Begin 2D mode with custom camera (2D)
        //    const clear: ray.Color = .{ .r = 0, .g = 0, .b = 0, .a = 0 };
        //    ray.ClearBackground(clear);
        //    inv.renderItems(lvl.ecs, a, &window_manager);
        //    anime.renderSprites(lvl.ecs, a, &window_manager, update_options);
        //    ray.EndMode2D();
        //}
        //ray.EndTextureMode();

        //bloom
        ////set bloom values

        ray.BeginDrawing();
        {
            //ray.BeginMode2D(camera);
            //ray.ClearBackground(ray.RAYWHITE); // Clear screen background

            //        Enable shader using the custom uniform
            if (light_shaders) {
                light_shader.shader.beginShaderMode();
            }
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
        }

        //if (bloom_shaders) {
        //    bloom_shader.beginShaderMode();

        //    ray.DrawTextureRec(
        //        bloom_layer.texture,
        //        .{
        //            .x = 0,
        //            .y = 0,
        //            .width = @floatFromInt(bloom_layer.texture.width),
        //            .height = @floatFromInt(-bloom_layer.texture.height),
        //        },
        //        .{ .x = 0, .y = 0 },
        //        ray.WHITE,
        //    );

        //    bloom_shader.endShaderMode();
        //}

        debugger.render(&window_manager);
        inv.renderPlayerInventory(lvl.ecs, a, &window_manager);
        //}
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
