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

const dvui = @import("dvui");

const ray = @import("raylib-import.zig").ray;
/// distance between two points
pub fn distanceBetween(a: ray.Vector2, b: ray.Vector2) f32 {
    const dx = a.x - b.x;
    const dy = a.y - b.y;

    return @sqrt(dx * dx + dy * dy);
}

/// normalizes a vector
pub fn normalize(v: ray.Vector2) ray.Vector2 {
    const mag = std.math.sqrt(v.x * v.x + v.y * v.y);
    return ray.Vector2{
        .x = v.x / mag,
        .y = v.y / mag,
    };
}

fn tof32(input: anytype) f32 {
    return @floatFromInt(input);
}

pub fn addVector2(a: ray.Vector2, b: ray.Vector2) ray.Vector2 {
    return .{ .x = a.x + b.x, .y = a.y + b.y };
}

pub fn scaleVector(a: ray.Vector2, scalar: anytype) ray.Vector2 {
    if (@TypeOf(scalar) == f32)
        return .{ .x = a.x * scalar, .y = a.y * scalar };

    return .{ .x = a.x * tof32(scalar), .y = a.y * tof32(scalar) };
}

pub fn getMagnitude(a: ray.Vector2) f32 {
    return @sqrt(a.x * a.x + a.y * a.y);
}

const vec_default: ray.Vector2 = .{ .x = 0, .y = 0 };

pub const Physics = struct {
    position: ray.Vector2 = vec_default,
    velocity: ray.Vector2 = vec_default,
    acceleration: ray.Vector2 = vec_default,
    mass: f32 = 10, //kg

    pub fn applyForce(self: *@This(), force: ray.Vector2) void {
        const acceleration = ray.Vector2{
            .x = force.x / self.mass,
            .y = force.y / self.mass,
        };
        self.acceleration.x += acceleration.x;
        self.acceleration.y += acceleration.y;
    }

    pub fn applyFriction(self: *@This(), friction_coefficient: f32) void {
        self.velocity.x *= (1 - friction_coefficient);
        self.velocity.y *= (1 - friction_coefficient);
    }

    /// gets the caching position for a physics component
    pub fn getCachePosition(self: Physics) ?struct { x: usize, y: usize } {
        if (self.position.x < 0 or self.position.y < 0) {
            return null;
        }
        return .{
            .x = @intFromFloat(@max(@divFloor(self.position.x, position_cache_scale), 0)),
            .y = @intFromFloat(@max(@divFloor(self.position.y, position_cache_scale), 0)),
        };
    }
};

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

pub fn directionVector(physics: ray.Vector2, target: ray.Vector2) ray.Vector2 {
    return normalize(.{ .x = target.x - physics.x, .y = target.y - physics.y });
}
///makes a physics system move towards a destination
//pub fn moveTowards(physics: *Component.Physics, destination: ray.Vector2, opt: options.Update) void {
//    const angle = getAngleBetween(physics.pos, destination);
//    physics.vel.x += physics.acceleration * @cos(angle) * opt.dt;
//    physics.vel.y += physics.acceleration * @sin(angle) * opt.dt;
//}

pub fn rotateVector2(point: ray.Vector2, angle_radians: f32, pivot: ray.Vector2) ray.Vector2 {
    const sin = std.math.sin(angle_radians);
    const cos = std.math.cos(angle_radians);

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
//pub fn moveAwayFrom(physics: *Component.Physics, destination: ray.Vector2, opt: options.Update) void {
//    moveTowards(physics, rotateVector2(destination, std.math.pi, physics.pos), opt);
//}

//IMPORTANT, controls the scale of the position cache relative to the map
pub const position_cache_scale: usize = 1;

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

        // Update velocity based on acceleration
        physics.velocity.x += physics.acceleration.x * opt.dt;
        physics.velocity.y += physics.acceleration.y * opt.dt;

        //store old position in case new position collides with walls
        const old_position = physics.position;
        physics.position.x += physics.velocity.x * opt.dt;

        //undo if the entity collides
        if (self.getMaybe(Component.Hitbox, member)) |hitbox| {
            if (self.getMaybe(Component.WallCollisions, member) != null and
                m.checkCollision(hitbox.getCollisionRect(physics.position)))
            {
                physics.position.x = old_position.x;
                physics.velocity.x *= 0.5;
            }
        }

        physics.position.y += physics.velocity.y * opt.dt;

        if (self.getMaybe(Component.Hitbox, member)) |hitbox| {
            if (self.getMaybe(Component.WallCollisions, member) != null and
                m.checkCollision(hitbox.getCollisionRect(physics.position)))
            {
                physics.position.y = old_position.y;
                physics.velocity.y *= 0.5;
            }
        }

        //apply friction
        const friction = 10;
        physics.applyFriction(friction * opt.dt);

        // Reset acceleration for the next frame (forces need to be reapplied)
        physics.acceleration.x = 0;
        physics.acceleration.y = 0;

        //adding movement particles
        if (self.getMaybe(Component.MovementParticles, member)) |particles| {
            if (particles.cooldown_remaining_ms > 0) {
                particles.cooldown_remaining_ms -= opt.dtInMs();
            } else {
                const velocity_magnitude = @abs((physics.velocity.x + physics.velocity.y) / 2);
                const adjustment_factor: f32 = 0.2;

                if (velocity_magnitude > ecs.randomFloat() * adjustment_factor) {
                    const num_particles: usize = @intFromFloat(@floor(ecs.randomFloat() * 5));
                    for (0..num_particles * 3) |_| {
                        const particle = try arch.createParticle(self, a);
                        const entity_hitbox = self.getMaybe(Component.Hitbox, member) orelse &Component.Hitbox{};
                        try self.setComponent(a, particle, Component.Physics{
                            .position = .{
                                .x = physics.position.x + 0.3 + 0.2 * (ecs.randomFloat() - 0.5),
                                .y = physics.position.y + (entity_hitbox.bottom - entity_hitbox.top),
                            },
                            .velocity = .{
                                .x = (ecs.randomFloat() - 0.5) * opt.dt,
                                .y = (ecs.randomFloat() - 0.5) * opt.dt,
                            },
                        });
                    }
                    particles.cooldown_remaining_ms = 150 + ecs.randomFloat() * 200;
                }
            }
        }
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
    _ = opt; // autofix
    const systems = [_]type{ Component.Physics, Component.Hitbox, Component.EntityCollisions };
    const set = self.getSystemDomain(a, &systems);

    for (set) |member| {
        const physics = self.get(Component.Physics, member);

        const colliders = try coll.findCollidingEntities(self, a, m, member);
        for (colliders) |colliding_entity| {
            if (self.hasComponent(Component.EntityCollisions, colliding_entity)) {
                const colliding_entity_physics = self.get(Component.Physics, colliding_entity);
                applyCollisionForce(colliding_entity_physics, physics, 1);
                //moveAwayFrom(colliding_entity_physics, physics.pos, opt);
            }
        }
    }
}

fn applyCollisionForce(obj1: *Physics, obj2: *const Physics, restitution: f32) void {
    // Calculate normal vector
    var normal = ray.Vector2{
        .x = obj2.position.x - obj1.position.x,
        .y = obj2.position.y - obj1.position.y,
    };
    const distance: f32 = @sqrt(normal.x * normal.x + normal.y * normal.y);
    normal.x /= distance;
    normal.y /= distance;

    // Relative velocity in the normal direction
    const relative_velocity: ray.Vector2 = .{
        .x = obj2.velocity.x - obj1.velocity.x,
        .y = obj2.velocity.y - obj1.velocity.y,
    };
    const velocity_along_normal: f32 = relative_velocity.x * normal.x + relative_velocity.y * normal.y;

    // If objects are moving apart, no need to apply force
    if (velocity_along_normal > 0) {
        return;
    }

    // Calculate the impulse scalar
    const e = restitution; // Coefficient of restitution (1 for elastic, < 1 for inelastic)
    const inverse_mass1 = 1.0 / obj1.mass;
    const inverse_mass2 = 1.0 / obj2.mass;
    const j = -(1 + e) * velocity_along_normal / (inverse_mass1 + inverse_mass2);

    // Apply impulse force to both objects
    const impulse: ray.Vector2 = .{ .x = j * normal.x, .y = j * normal.y };

    // Apply the impulse as force to both objects
    obj1.applyForce(impulse);
}
