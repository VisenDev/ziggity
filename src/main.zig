const std = @import("std");
const cwd = @import("cwd.zig");
const entity = @import("entity.zig");
const State = @import("state.zig").State;
const c = @cImport({
    @cInclude("stdlib.h");
});

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

    var game = try State.init(allocator);
    const texture = game.texture_state.get("default");

    for (0..10) |_| {
        try game.entity_state.spawn(.{
            .position = entity.PositionComponent{
                .pos = .{
                    .x = 1,
                    .y = 1,
                },
            },
            .renderer = entity.RenderComponent{
                .texture = texture,
            },
        });
    }

    while (!ray.WindowShouldClose()) {
        try game.entity_state.update(1.0);

        ray.BeginDrawing();
        {
            ray.ClearBackground(ray.RAYWHITE);
            ray.DrawText("Hello, World!", 190, 200, 20, ray.LIGHTGRAY);

            //game.map_state.render(game.tiles, 5.0);
            try game.entity_state.render(5.0);
        }
        ray.EndDrawing();
    }
}
