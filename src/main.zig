const std = @import("std");
const state = @import("state.zig");
const cwd = @import("cwd.zig");

const Arena = std.heap.ArenaAllocator;
const page_allocator = std.heap.page_allocator;
const gpa = std.heap.GeneralPurposeAllocator(.{}){};

const ray = @cImport({
    @cInclude("raylib.h");
});

pub fn main() !void {
    try cwd.resolveCWD();

    //arena allocation
    var my_arena = Arena.init(page_allocator);
    defer my_arena.deinit();
    const allocator = my_arena.allocator();

    ray.InitWindow(800, 450, "raylib [core] example - basic window");
    defer ray.CloseWindow();
    ray.SetTargetFPS(60);

    var game = try state.createGameState(allocator);

    _ = try game.entity_state.newEntity(&game.texture_state);
    _ = try game.entity_state.newEntity(&game.texture_state);
    _ = try game.entity_state.newEntity(&game.texture_state);
    _ = try game.entity_state.newEntity(&game.texture_state);
    _ = try game.entity_state.newEntity(&game.texture_state);
    _ = try game.entity_state.newEntity(&game.texture_state);

    while (!ray.WindowShouldClose()) {
        try game.entity_state.update(1.0);

        ray.BeginDrawing();
        defer ray.EndDrawing();

        ray.ClearBackground(ray.RAYWHITE);
        ray.DrawText("Hello, World!", 190, 200, 20, ray.LIGHTGRAY);
        try game.entity_state.render(5.0);
    }
}
