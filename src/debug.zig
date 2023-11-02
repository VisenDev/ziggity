const std = @import("std");
const tile = @import("tiles.zig");
const anime = @import("animation.zig");
const map = @import("map.zig");
const texture = @import("textures.zig");
const key = @import("keybindings.zig");
const options = @import("options.zig");
const ecs = @import("ecs.zig");
const SparseSet = @import("sparse_set.zig").SparseSet;
const Grid = @import("grid.zig").Grid;
const coll = @import("collisions.zig");
const Component = @import("components.zig");
const intersection = @import("sparse_set.zig").intersection;
const sys = @import("systems.zig");
const ray = @cImport({
    @cInclude("raylib.h");
});

const font_size: c_int = 20;

pub fn renderHitboxes(self: *ecs.ECS, a: std.mem.Allocator, tile_state_resolution: usize) void {
    const systems = [_]type{ Component.physics, Component.hitbox };
    const set = self.getSystemDomain(a, &systems);

    for (set) |member| {
        const physics = self.get(Component.physics, member);
        const hitbox = self.get(Component.hitbox, member);

        const rect = hitbox.getCollisionRect(physics.pos);
        ray.DrawRectangleLinesEx(sys.scaleRectangle(rect, tile_state_resolution), 1, ray.ColorAlpha(ray.RAYWHITE, 0.4));
    }
}

pub fn renderEntityCoordinates() void {}

var buf: [1024]u8 = undefined;

pub fn renderPositionCache(self: *ecs.ECS, a: std.mem.Allocator, tile_state_resolution: usize) void {
    _ = a;
    for (0..self.position_cache.getWidth()) |x| {
        for (0..self.position_cache.getHeight()) |y| {
            const contents = self.position_cache.get(x, y).?;
            if (contents.items.len > 0) {
                const position = ray.Vector2{
                    .x = sys.tof32(x * sys.position_cache_scale * tile_state_resolution),
                    .y = sys.tof32(y * sys.position_cache_scale * tile_state_resolution),
                };
                const size = sys.tof32(sys.position_cache_scale * tile_state_resolution);
                ray.DrawRectangleLinesEx(.{ .x = position.x, .y = position.y, .width = size, .height = size }, 1, ray.ColorAlpha(ray.YELLOW, 0.5));

                _ = std.fmt.bufPrintZ(&buf, "{}", .{contents.items.len}) catch unreachable;
                ray.DrawTextEx(ray.GetFontDefault(), &buf, position, font_size / 2, 2, ray.RAYWHITE);
            }
        }
    }
}

pub fn renderEntityCount(self: *ecs.ECS) !void {
    const count = self.capacity - self.availible_ids.items.len;

    _ = try std.fmt.bufPrintZ(&buf, "{} entities", .{count});
    ray.DrawText(&buf, 15, 45, font_size, ray.RAYWHITE);
}
