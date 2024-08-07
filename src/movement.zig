const std = @import("std");
const coll = @import("collisions.zig");
const arch = @import("archetypes.zig");
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

pub fn distance(a: ray.Vector2, b: ray.Vector2) f32 {
    const dx = a.x - b.x;
    const dy = a.y - b.y;

    return @sqrt(dx * dx + dy * dy);
}

///normalizes a vector
pub fn normalize(v: ray.Vector2) ray.Vector2 {
    const mag = std.math.sqrt(v.x * v.x + v.y * v.y);
    return ray.Vector2{
        .x = v.x / mag,
        .y = v.y / mag,
    };
}

//pub fn getAngle(v: ray.Vector2) f32 {
//    const angle = std.math.atan2(v.y, v.x); //radians
//    const degrees = 180 * angle / std.math.pi; //degrees
//    return degrees; //round number, avoid decimal fragments
//}

//const Radians = f32;
//pub fn getAngleBetween(v1: ray.Vector2, v2: ray.Vector2) Radians {
//    const dot_product = v1.x * v2.x + v1.y * v2.y;
//    const determinant = v1.x * v2.y - v1.y * v2.x;
//    var angle: Radians = std.math.atan2(determinant, dot_product);
//    if (angle < 0) {
//        angle += 2 * std.math.pi;
//    }
//    return angle;
//}

const Radians = f32;
pub fn getAngleBetween(v1: ray.Vector2, v2: ray.Vector2) Radians {
    const dx = v2.x - v1.x;
    const dy = v2.y - v1.y;
    var angle: f32 = std.math.atan2(dy, dx);

    if (angle < 0) {
        angle += 2 * std.math.pi;
    }
    return angle;
}

test "getAngle" {
    try std.testing.expectEqual(@as(f32, 0), getAngleBetween(.{ .x = 1, .y = 1 }, .{ .x = 5, .y = 1 }));
    try std.testing.expectEqual(@as(f32, std.math.pi), getAngleBetween(.{ .x = 1, .y = 1 }, .{ .x = -1, .y = 1 }));
    try std.testing.expectEqual(@as(f32, std.math.pi / 4.0), getAngleBetween(.{ .x = -1, .y = -1 }, .{ .x = 2, .y = 2 }));
    try std.testing.expectEqual(@as(f32, @as(f32, std.math.pi) + std.math.pi / 4.0), getAngleBetween(.{ .x = 1, .y = 1 }, .{ .x = -2, .y = -2 }));
}

///makes a physics system move towards a destination
pub fn moveTowards(physics: *Component.Physics, destination: ray.Vector2, opt: options.Update) void {
    const angle = getAngleBetween(physics.pos, destination);
    physics.vel.x += physics.acceleration * @cos(angle) * opt.dt;
    physics.vel.y += physics.acceleration * @sin(angle) * opt.dt;
}

pub fn rotateVector2(point: ray.Vector2, angle: f32, pivot: ray.Vector2) ray.Vector2 {
    const sin = std.math.sin(angle);
    const cos = std.math.cos(angle);

    var p = point;

    // translate point back to origin:
    p.x -= pivot.x;
    p.y -= pivot.y;

    // rotate p
    const xnew = p.x * cos - p.y * sin;
    const ynew = p.x * sin + p.y * cos;

    // translate point back:
    const result: ray.Vector2 = .{
        .x = xnew + pivot.x,
        .y = ynew + pivot.y,
    };
    return result;
}

///makes a physics system move away from a destination
pub fn moveAwayFrom(physics: *Component.Physics, destination: ray.Vector2, opt: options.Update) void {
    moveTowards(physics, rotateVector2(destination, std.math.pi, physics.pos), opt);
}

pub fn updateMovementSystem(
    self: *ecs.ECS,
    a: std.mem.Allocator,
    m: *const map.MapState,
    opt: options.Update,
) !void {
    const systems = [_]type{Component.Physics};
    const set = self.getSystemDomain(a, &systems);

    for (set) |member| {
        var physics = self.get(Component.Physics, member);

        const old_position = physics.pos;
        physics.pos.x += physics.vel.x;

        //undo if the entity collides
        if (self.getMaybe(Component.Hitbox, member)) |hitbox| {
            if (self.getMaybe(Component.WallCollisions, member) != null and
                m.checkCollision(hitbox.getCollisionRect(physics.pos)))
            {
                physics.pos.x = old_position.x;
                physics.vel.x *= 0.5;
            }
        }

        physics.pos.y += physics.vel.y;

        if (self.getMaybe(Component.Hitbox, member)) |hitbox| {
            if (self.getMaybe(Component.WallCollisions, member) != null and
                m.checkCollision(hitbox.getCollisionRect(physics.pos)))
            {
                physics.pos.y = old_position.y;
                physics.vel.y *= 0.5;
            }
        }

        //adding movement particles
        if (self.getMaybe(Component.MovementParticles, member)) |_| {
            const velocity_magnitude = @abs((physics.vel.x + physics.vel.y) / 2);

            const adjustment_factor: f32 = 0.2;

            if (velocity_magnitude > ecs.randomFloat() * adjustment_factor) {
                const num_particles: usize = @intFromFloat(@floor(ecs.randomFloat() * 5));
                for (0..num_particles) |_| {
                    const particle = try arch.createParticle(self, a);
                    const entity_hitbox = self.getMaybe(Component.Hitbox, member) orelse &Component.Hitbox{};
                    try self.setComponent(a, particle, Component.Physics{
                        .pos = .{
                            .x = physics.pos.x + 0.3 + 0.2 * (ecs.randomFloat() - 0.5),
                            .y = physics.pos.y + (entity_hitbox.bottom - entity_hitbox.top),
                        },
                        .vel = .{
                            .x = (ecs.randomFloat() - 0.5) * opt.dt,
                            .y = (ecs.randomFloat() - 0.5) * opt.dt,
                        },
                    });
                }
            }
        }

        physics.vel.x *= physics.friction;
        physics.vel.y *= physics.friction;
    }
}

pub fn updatePositionCacheSystem(
    self: *ecs.ECS,
    a: std.mem.Allocator,
    m: *const map.MapState,
    opt: options.Update,
) !void {
    _ = opt; // autofix
    //
    const data = struct {
        const Location = struct { x: usize = 0, y: usize = 0 };
        const size = 1024;
        var cache_locations_to_clear: [size]Location = .{.{}} ** size;
        var num_cache_locations: usize = 0;

        pub fn addLocation(location: Location) void {
            if (num_cache_locations >= size) return;
            cache_locations_to_clear[num_cache_locations] = location;
            num_cache_locations += 1;
        }
    };

    for (data.cache_locations_to_clear[0..data.num_cache_locations]) |loc| {
        m.grid.at(loc.x, loc.y).?.clearCache();
    }

    //only cache entities with both a physics and hitbox component
    const cache_systems = [_]type{ Component.Physics, Component.Hitbox };

    //cache positions
    for (self.getSystemDomain(a, &cache_systems)) |member| {
        const physics = self.get(Component.Physics, member);
        if (physics.getCachePosition()) |cache_pos| {
            m.grid.at(cache_pos.x, cache_pos.y).?.appendCache(member);
            data.addLocation(.{ .x = cache_pos.x, .y = cache_pos.y });
        }
    }
}

pub fn updateEntitySeparationSystem(
    self: *ecs.ECS,
    a: std.mem.Allocator,
    m: *const map.MapState,
    opt: options.Update,
) !void {
    const systems = [_]type{ Component.Physics, Component.Hitbox, Component.EntityCollisions };
    const set = self.getSystemDomain(a, &systems);

    for (set) |member| {
        const physics = self.get(Component.Physics, member);

        const colliders = try coll.findCollidingEntities(self, a, m, member);
        for (colliders) |colliding_entity| {
            if (self.hasComponent(Component.EntityCollisions, colliding_entity)) {
                const colliding_entity_physics = self.get(Component.Physics, colliding_entity);
                moveAwayFrom(colliding_entity_physics, physics.pos, opt);
            }
        }
    }
}
