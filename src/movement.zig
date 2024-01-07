const std = @import("std");
const api = @import("api.zig");
const ziglua = @import("ziglua");
const Lua = ziglua.Lua;
const tile = @import("tiles.zig");
const anime = @import("animation.zig");
const map = @import("map.zig");
const texture = @import("textures.zig");
const key = @import("keybindings.zig");
const options = @import("options.zig");
const ecs = @import("ecs.zig");
const SparseSet = @import("sparse_set.zig").SparseSet;
const Grid = @import("grid.zig").Grid;
pub const Component = @import("components.zig");
const intersection = @import("sparse_set.zig").intersection;
const ray = @cImport({
    @cInclude("raylib.h");
});

///normalizes a vector
pub fn normalize(v: ray.Vector2) ray.Vector2 {
    const mag = std.math.sqrt(v.x * v.x + v.y * v.y);
    return ray.Vector2{
        .x = v.x / mag,
        .y = v.y / mag,
    };
}

///makes a physics system move towards a destination
pub fn moveTowards(physics: *Component.physics, destination: ray.Vector2, opt: options.Update) void {
    const normal = normalize(destination);
    physics.vel.x += normal.x * physics.acceleration * opt.dt;
    physics.vel.y += normal.y * physics.acceleration * opt.dt;
}

pub fn updateMovementSystem(
    self: *ecs.ECS,
    a: std.mem.Allocator,
    l: *Lua,
    m: *const map.MapState,
    animations: *const anime.AnimationState,
    opt: options.Update,
) !void {
    _ = animations;
    const systems = [_]type{Component.physics};
    const set = self.getSystemDomain(a, &systems);

    for (set) |member| {
        var physics = self.get(Component.physics, member);

        const old_position = physics.pos;
        physics.pos.x += physics.vel.x;

        //undo if the entity collides
        if (self.getMaybe(Component.hitbox, member)) |hitbox| {
            if (self.getMaybe(Component.wall_collisions, member) != null and
                m.checkCollision(hitbox.getCollisionRect(physics.pos)))
                physics.pos.x = old_position.x;
        }

        physics.pos.y += physics.vel.y;

        if (self.getMaybe(Component.hitbox, member)) |hitbox| {
            if (self.getMaybe(Component.wall_collisions, member) != null and
                m.checkCollision(hitbox.getCollisionRect(physics.pos)))
                physics.pos.y = old_position.y;
        }

        physics.vel.x *= physics.friction;
        physics.vel.y *= physics.friction;

        if (self.getMaybe(Component.movement_particles, member)) |_| {
            if (physics.pos.x != old_position.x or physics.pos.y != old_position.y) {
                var copy = a;
                const particle = try l.autoCall(?usize, "SpawnMovementParticle", .{ self, &copy }) orelse continue;
                try self.setComponent(a, particle, Component.physics{
                    .pos = .{
                        .x = physics.pos.x + 0.3 + 0.2 * (ecs.randomFloat() - 0.5),
                        .y = physics.pos.y + 0.8 * (ecs.randomFloat() - 0.5),
                    },
                    .vel = .{
                        .x = (ecs.randomFloat() - 0.5) * opt.dt,
                        .y = (ecs.randomFloat() - 0.5) * opt.dt,
                    },
                });
            }
        }
    }

    //clear position cache
    for (0..self.position_cache.getWidth()) |x| {
        for (0..self.position_cache.getHeight()) |y| {
            self.position_cache.get(x, y).?.clearRetainingCapacity();
        }
    }

    //only cache entities with both a physics and hitbox component
    const cache_systems = [_]type{ Component.physics, Component.hitbox };

    //cache positions
    for (self.getSystemDomain(a, &cache_systems)) |member| {
        const physics = self.get(Component.physics, member);

        const pos = physics.getCachePosition();

        if (pos.x < 0 or pos.y < 0) continue;

        var cache_list = try self.position_cache.getOrSet(a, pos.x, pos.y, .{});
        try cache_list.append(a, member);
    }

    //calculate collisions
}
