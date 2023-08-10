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

    var G = try state.createGameState(allocator);
    _ = G;

    while (!ray.WindowShouldClose()) {
        ray.BeginDrawing();
        defer ray.EndDrawing();

        ray.ClearBackground(ray.RAYWHITE);
        ray.DrawText("Hello, World!", 190, 200, 20, ray.LIGHTGRAY);
    }
}
