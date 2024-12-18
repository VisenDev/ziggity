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

//const ray = dvui.backend.c;
//const ray = @cImport({
//    @cInclude("raylib.h");
//    @cInclude("raymath.h");
//    @cInclude("rlgl.h");
//    @cInclude("raygui.h");
//});
const ray = @import("raylib-import.zig").ray;

//const gl = @cImport({
//@cInclude("glad.h");
//});

const profiler = @import("profiler");

const dvui = @import("dvui");
const RaylibBackend = dvui.backend;

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
    var gpa = std.heap.GeneralPurposeAllocator(.{
        .retain_metadata = true,
        .enable_memory_limit = true,
        .verbose_log = true,
    }){};
    defer _ = gpa.detectLeaks();
    var my_arena = Arena.init(gpa.allocator());
    defer my_arena.deinit();
    const a = my_arena.allocator();

    ray.SetConfigFlags(ray.FLAG_WINDOW_RESIZABLE);
    ray.SetConfigFlags(ray.FLAG_VSYNC_HINT); //disable this flag to test max fps
    ray.InitWindow(800, 450, "ziggity");
    ray.SetTargetFPS(60);
    defer ray.CloseWindow();

    //const music_player = try std.Thread.spawn(.{}, playSound, .{});
    //defer music_player.detach();

    try profiler.init(.{});
    defer {
        profiler.dump("profile.json") catch |e| std.log.err("profile dump failed: {}", .{e});
        profiler.deinit();
    }

    var lua = try api.initLuaApi(a);
    defer lua.deinit();

    var dvui_backend = RaylibBackend.init(a);
    defer dvui_backend.deinit();
    //dvui_backend.log_events = true;

    var ui = try dvui.Window.init(@src(), a, dvui_backend.backend(), .{});
    defer ui.deinit();

    var current_window = menu.NextWindow.main_menu;
    var save_id: []u8 = "";

    while (!ray.WindowShouldClose()) {
        std.debug.print("WINDOW: {s}\n", .{save_id});
        current_window = switch (current_window) {
            .quit => break,
            .main_menu => try menu.drawMainMenu(a, &ui, &dvui_backend),
            .save_menu => try menu.drawSaveSelectMenu(a, &ui, &dvui_backend, &save_id),
            .config_menu => err.crashToMainMenu("config_menu_not_implemented_yet"),
            .new_save => try menu.drawNewSaveMenu(a, lua, &ui, &dvui_backend),
            .game => try runGame(a, lua, save_id),
        };
    }
}

fn runGame(a: std.mem.Allocator, lua: *Lua, current_save: []const u8) !menu.NextWindow {
    const zone = profiler.begin(@src(), "runGame");
    defer zone.end();

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

    var target = shade.RenderTexture.init(100, 100);
    defer target.deinit();

    var light_texture = shade.RenderTexture.init(100, 100);
    defer light_texture.deinit();

    //var target = ray.LoadRenderTexture(ray.GetScreenWidth(), ray.GetScreenHeight());
    //defer ray.UnloadRenderTexture(target);

    //var bloom_layer = ray.LoadRenderTexture(ray.GetScreenWidth(), ray.GetScreenHeight());
    //defer ray.UnloadRenderTexture(bloom_layer);

    //const bloom_shader = try shade.loadFragmentShader(a, "blur.fs");
    //defer ray.UnloadShader(bloom_shader);
    //var bloom_shader = try shade.FragShader.init(a, "blur.fs");
    //defer bloom_shader.deinit();

    var debugger = try debug.DebugRenderer.init(a);
    defer debugger.deinit();

    var dtlog = debug.DeltaTimeLog{};

    var update_options = options.Update.init(&debugger);

    //temporary variable, TODO add this functionality to window manager
    //var bloom_shaders = true;
    //var light_shaders = true;

    var show_light_rendertexture = false;

    while (!ray.WindowShouldClose()) {
        const tick_zone = profiler.begin(@src(), "tick_game");
        defer tick_zone.end();

        target.updateDimentions();
        light_texture.updateDimentions();

        //debug on or off
        if (window_manager.keybindings.isPressed("debug_mode")) {
            debugger.enabled = !debugger.enabled;
        }

        //configure update options
        window_manager.updateCameraPosition(a, lvl);
        update_options.update();

        //log delta time
        dtlog.record(update_options.dt);

        //reset mouse layers
        window_manager.resetMouseOwner();

        const debug_zone = profiler.begin(@src(), "debug_zone");
        debugger.addText("FPS: {}", .{ray.GetFPS()});
        debugger.addText("Entity Count: {}", .{lvl.ecs.getNumEntities()});
        if (debugger.addTextButton(&window_manager, "[Toggle Light Shaders]", .{})) {
            light_shader.shader.enabled = !light_shader.shader.enabled;
        }
        if (debugger.addTextButton(&window_manager, "[Show Light Texture]", .{})) show_light_rendertexture = !show_light_rendertexture;
        if (debugger.addTextButton(&window_manager, "[Save]", .{})) try lvl.save(a);
        if (debugger.addTextButton(&window_manager, "[Main Menu]", .{})) return .main_menu;
        debug_zone.end();

        const movement_zone = profiler.begin(@src(), "movement_zone");
        try move.updateEntitySeparationSystem(lvl.ecs, a, lvl.map, update_options);
        try move.updateMovementSystem(lvl.ecs, a, lvl.map, update_options);
        try move.updatePositionCacheSystem(lvl.ecs, a, lvl.map, update_options);
        movement_zone.end();

        const inventory_zone = profiler.begin(@src(), "inventory_zone");
        try inv.updateInventorySystem(lvl.ecs, a, &window_manager, lvl.map, update_options);
        inventory_zone.end();

        const player_zone = profiler.begin(@src(), "player_zone");
        try play.updatePlayerSystem(lvl.ecs, a, lua, &window_manager, update_options);
        player_zone.end();

        const item_zone = profiler.begin(@src(), "item_zone");
        try inv.updateItemSystem(lvl.ecs, a, &window_manager, update_options);
        item_zone.end();

        const health_zone = profiler.begin(@src(), "health_zone");
        try sys.updateLifetimeSystem(lvl.ecs, a, update_options);
        try sys.updateDeathSystem(lvl.ecs, a, lua, update_options);
        sys.updateHealthCooldownSystem(lvl.ecs, a, update_options);
        try sys.updateDamageSystem(lvl.ecs, a, lvl.map, update_options);
        health_zone.end();

        const update_animation_zone = profiler.begin(@src(), "update_animation_zone");
        sys.updateSpriteSystem(lvl.ecs, a, &window_manager, update_options);
        try sys.trimAnimationEntitySystem(lvl.ecs, a, update_options);
        update_animation_zone.end();

        const ai_zone = profiler.begin(@src(), "ai_zone");
        try ai.updateControllerSystem(lvl.ecs, a, update_options);
        ai_zone.end();
        //try light.updateLightingSystem(lvl.ecs, a, &light_shader, update_options);

        //draw main
        ray.BeginDrawing();
        {
            const render_zone = profiler.begin(@src(), "main_render_zone");
            defer render_zone.end();

            ray.BeginTextureMode(target.raw_render_texture);
            ray.BeginMode2D(window_manager.camera);
            ray.ClearBackground(ray.BLACK);

            const render_map_zone = profiler.begin(@src(), "render_map_zone");
            lvl.map.renderMain(a, &window_manager, lvl.ecs);
            render_map_zone.end();

            const render_map_border_zone = profiler.begin(@src(), "render_map_border_zone");
            lvl.map.renderBorders(a, &window_manager, lvl.ecs);
            render_map_border_zone.end();

            const render_item_zone = profiler.begin(@src(), "render_item_zone");
            inv.renderItems(lvl.ecs, a, &window_manager);
            render_item_zone.end();

            const render_sprite_zone = profiler.begin(@src(), "render_sprite_zone");
            anime.renderSprites(lvl.ecs, a, &window_manager, update_options);
            render_sprite_zone.end();

            //try light_shader.render(&window_manager);

            //gl.glEnable(gl.GL_STENCIL_TEST);
            ray.EndMode2D();
            ray.EndTextureMode();
        }

        //std.debug.assert(target.texture_mode == false);

        {
            const render_zone = profiler.begin(@src(), "inventory_render_zone");
            defer render_zone.end();

            ray.BeginTextureMode(light_texture.raw_render_texture);
            ray.BeginMode2D(window_manager.camera);
            //light_texture.beginTextureMode();
            //defer light_texture.endTextureMode();
            //ray.ClearBackground(ray.GRAY);

            //lvl.map.renderMain(a, &window_manager, lvl.ecs);
            //lvl.map.renderBorders(a, &window_manager, lvl.ecs);

            inv.renderItems(lvl.ecs, a, &window_manager);
            //ray.DrawRectangle(100, 100, 200, 200, ray.RAYWHITE);
            //ray.DrawRectangle(0, 0, 2000, 2000, ray.RAYWHITE);
            //anime.renderSprites(lvl.ecs, a, &window_manager, update_options);

            //try light_shader.render(&window_manager);

            //gl.glEnable(gl.GL_STENCIL_TEST);
            ray.EndMode2D();
            ray.EndTextureMode();
        }

        //std.debug.assert(light_texture.texture_mode == false);

        //try light_shader.shader.setShaderValue("texture1", ray.Texture2D, &target.texture);
        //ray.BeginShaderMode(light_shader.shader.raw_shader); // Enable our custom shader for next shapes/textures drawings
        //ray.DrawTexture(bloom_layer.texture, 0, 0, ray.WHITE); // Drawing BLANK texture, all magic happens on shader
        //ray.EndShaderMode(); // Disable our custom shader, return to default shader
        //const value: f32 = 0.005;
        //try bloom_shader.setShaderValue("blur_size", f32, &value);

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

        //try light_shader.shader.setShaderValue("ambientColor", shade.Vec4, &ray.WHITE);

        //const value: f32 = 0.3;
        //try light_shader.shader.setShaderValue("lightRadius", f32, &value);

        {
            const render_zone = profiler.begin(@src(), "shader_render_zone");
            defer render_zone.end();

            const texture0: c_int = 0;
            ray.rlActiveTextureSlot(0);
            ray.rlEnableTexture(target.texture().id);
            //const texture1: c_int = 1;
            //gl.glActiveTexture(gl.GL_TEXTURE1);
            //gl.glBindTexture(gl.GL_TEXTURE_2D, light_texture.texture().id);
            try light_shader.shader.setShaderValue("texture0", i32, &texture0);
            //try light_shader.shader.setShaderValue("texture1", i32, &texture1);
            target.render(light_shader.shader);
            //ray.BeginMode2D(camera);
            //ray.ClearBackground(ray.RAYWHITE); // Clear screen background

            ////        Enable shader using the custom uniform
            //if (light_shaders) {
            //    light_shader.shader.beginShaderMode();
            //}
            //// NOTE: Render texture must be y-flipped due to default OpenGL coordinates (left-bottom)
            //ray.DrawTextureRec(
            //    target.texture,
            //    .{
            //        .x = 0,
            //        .y = 0,
            //        .width = @floatFromInt(target.texture.width),
            //        .height = @floatFromInt(-target.texture.height),
            //    },
            //    .{ .x = 0, .y = 0 },
            //    ray.WHITE,
            //);
            //ray.EndShaderMode();

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
            //if (show_light_rendertexture) {
            //    light_texture.render(null);
            //}

            const shader_batch_zone = profiler.begin(@src(), "render_batched");
            //ray.rlDrawRenderBatchActive();
            shader_batch_zone.end();

            debugger.render(&window_manager);
            dtlog.render();
            inv.renderPlayerInventory(lvl.ecs, a, &window_manager);
        }

        ray.EndDrawing();
        //endDrawing();

        if (ray.IsKeyPressed('Q')) {
            return .quit;
        }
    }
    return .quit;
}

pub fn endDrawing() void {
    const sleep_zone = profiler.begin(@src(), "end_drawing_zone");
    var a = profiler.begin(@src(), "ray_end_drawing");
    ray.EndDrawing();
    a.end();
    a = profiler.begin(@src(), "draw_render_batch_active");
    ray.rlDrawRenderBatchActive();
    a.end();
    a = profiler.begin(@src(), "swap_screen_buffer");
    ray.SwapScreenBuffer();
    a.end();
    a = profiler.begin(@src(), "poll_input_events");
    ray.PollInputEvents();
    a.end();
    a = profiler.begin(@src(), "wait_time");
    //    ray.WaitTime(0.001);
    a.end();
    sleep_zone.end();
}

test "unit tests" {
    @import("std").testing.refAllDeclsRecursive(@This());
}
