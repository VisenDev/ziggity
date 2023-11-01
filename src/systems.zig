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
pub const Component = @import("components.zig");
const intersection = @import("sparse_set.zig").intersection;
const ray = @cImport({
    @cInclude("raylib.h");
});

fn distance(a: ray.Vector2, b: ray.Vector2) f32 {
    const dx = a.x - b.x;
    const dy = a.y - b.y;

    return @sqrt(dx * dx + dy * dy);
}

pub fn updateHostileAiSystem(self: *ecs.ECS, a: std.mem.Allocator, opt: options.Update) void {
    _ = opt;

    const systems = [_]type{ Component.mind, Component.tracker };
    const set = self.getSystemDomain(a, &systems);

    for (set) |member| {
        var mind = self.get(Component.mind, member);
        var tracker = self.get(Component.mind, member);
        _ = tracker;

        switch (mind.activity) {}
    }
}

pub fn normalize(v: ray.Vector2) ray.Vector2 {
    const mag = std.math.sqrt(v.x * v.x + v.y * v.y);
    return ray.Vector2{
        .x = v.x / mag,
        .y = v.y / mag,
    };
}

//makes a physics system move towards a destination
pub fn moveTowards(physics: *Component.physics, destination: ray.Vector2, opt: options.Update) void {
    const normal = normalize(destination);
    physics.vel.x += normal.x * physics.acceleration * opt.dt;
    physics.vel.y += normal.y * physics.acceleration * opt.dt;
}

pub fn updateWanderingSystem(self: *ecs.ECS, a: std.mem.Allocator, opt: options.Update) void {
    const systems = [_]type{ Component.physics, Component.wanderer };
    const set = self.getSystemDomain(a, &systems);

    for (set) |member| {
        var wanderer = self.get(Component.wanderer, member);

        switch (wanderer.state) {
            .arrived => {
                wanderer.cooldown = opt.dt * 300 * ecs.randomFloat();
                wanderer.state = .waiting;
            },
            .waiting => {
                wanderer.cooldown -= opt.dt;
                if (wanderer.cooldown < 0) {
                    wanderer.state = .selecting;
                }
            },
            .selecting => {
                const random_destination = ecs.randomVector2(50, 50);
                wanderer.destination = random_destination;
                wanderer.state = .travelling;
                wanderer.cooldown = opt.dt * 300 * ecs.randomFloat();
            },
            .travelling => {
                var physics = self.get(Component.physics, member);
                moveTowards(physics, wanderer.destination, opt);
                wanderer.cooldown -= opt.dt;

                if (distance(physics.pos, wanderer.destination) < 1 or wanderer.cooldown <= 0) {
                    wanderer.state = .arrived;
                }
            },
        }
    }
}

pub fn checkCollision(
    physics_1: Component.physics,
    hitbox_1: Component.hitbox,
    physics_2: Component.physics,
    hitbox_2: Component.hitbox,
) bool {
    const rect_1 = ray.Rectangle{
        .x = physics_1.pos.x - hitbox_1.left,
        .y = physics_1.pos.y - hitbox_1.top,
        .width = hitbox_1.left + hitbox_1.right,
        .height = hitbox_1.top + hitbox_1.bottom,
    };

    const rect_2 = ray.Rectangle{
        .x = physics_2.pos.x - hitbox_2.left,
        .y = physics_2.pos.y - hitbox_2.top,
        .width = hitbox_2.left + hitbox_2.right,
        .height = hitbox_2.top + hitbox_2.bottom,
    };

    return ray.CheckCollisionRecs(rect_1, rect_2);
}

const position_cache_scaling_factor = 4;
///returns the position cache position from a coordinate
fn cachePosition(pos: ray.Vector2) struct { x: usize, y: usize } {
    return .{
        .x = @intFromFloat(@max(@divFloor(pos.x, position_cache_scaling_factor), 0)),
        .y = @intFromFloat(@max(@divFloor(pos.y, position_cache_scaling_factor), 0)),
    };
}

pub fn findCollidingEntities(
    self: *ecs.ECS,
    a: std.mem.Allocator,
    id: usize,
) ![]usize {
    self.id_buffer.clearRetainingCapacity();

    const physics = self.getMaybe(Component.physics, id) orelse return &{};
    const hitbox = self.getMaybe(Component.hitbox, id) orelse return &{};

    const pos = cachePosition(physics.pos);
    const neighbor_list = self.position_cache.findNeighbors(pos.x, pos.y);
    for (neighbor_list) |neighbor| {
        for (neighbor.items) |neighbor_id| {
            const neighbor_physics = self.getMaybe(Component.physics, neighbor_id) orelse continue;
            const neighbor_hitbox = self.getMaybe(Component.hitbox, neighbor_id) orelse continue;

            if (!checkCollision(physics, hitbox, neighbor_physics, neighbor_hitbox)) continue;
            self.id_buffer.append(a, id);
        }
    }
    return self.id_buffer.items;
}

pub fn updateMovementSystem(
    self: *ecs.ECS,
    a: std.mem.Allocator,
    m: *const map.MapState,
    animations: *const anime.AnimationState,
    opt: options.Update,
) !void {
    _ = m;
    _ = animations;
    const systems = [_]type{Component.physics};
    const set = self.getSystemDomain(a, &systems);

    for (set) |member| {
        var physics = self.get(Component.physics, member);

        const old_position = physics.pos;

        physics.pos.x += physics.vel.x;
        physics.pos.y += physics.vel.y;

        physics.vel.x *= physics.friction;
        physics.vel.y *= physics.friction;

        //undo if the entity collides
        if (self.getMaybe(Component.hitbox, member)) |hitbox| {
            _ = hitbox;
            //TODO add collision with map detection
            //physics.pos = old_position;
        }

        if (self.getMaybe(Component.movement_particles, member)) |_| {
            if (physics.pos.x != old_position.x or physics.pos.y != old_position.y) {
                const particle = self.newEntity(a).?;
                self.addComponent(a, particle, Component.health{}) catch return;
                self.addComponent(
                    a,
                    particle,
                    Component.physics{
                        .pos = .{
                            .x = physics.pos.x + 0.3 + 0.2 * (ecs.randomFloat() - 0.5),
                            .y = physics.pos.y + 1 + 0.2 * (ecs.randomFloat() - 0.5),
                        },
                        .vel = .{
                            .x = (ecs.randomFloat() - 0.5) * opt.dt,
                            .y = (ecs.randomFloat() - 0.5) * opt.dt,
                        },
                    },
                ) catch return;

                self.addComponent(
                    a,
                    particle,
                    Component.sprite{
                        .player = .{ .animation_name = "particle" },
                    },
                ) catch return;
                self.addComponent(a, particle, Component.health_trickle{}) catch return;
            }
        }
    }

    //clear position cache
    for (0..self.position_cache.getWidth()) |x| {
        for (0..self.position_cache.getHeight()) |y| {
            self.position_cache.get(x, y).?.clearRetainingCapacity();
        }
    }

    //cache positions
    for (set) |member| {
        const physics = self.get(Component.physics, member);

        const x: usize = @intFromFloat(@max(@divFloor(physics.pos.x, position_cache_scaling_factor), 0));
        const y: usize = @intFromFloat(@max(@divFloor(physics.pos.y, position_cache_scaling_factor), 0));

        if (x < 0 or y < 0) continue;

        var cache_list = try self.position_cache.getOrSet(a, x, y, .{});
        try cache_list.append(a, member);
    }

    //calculate collisions
}

pub fn updatePlayerSystem(
    self: *ecs.ECS,
    a: std.mem.Allocator,
    keys: key.KeyBindings,
    opt: options.Update,
) void {
    const systems = [_]type{ Component.is_player, Component.physics };
    const set = self.getSystemDomain(a, &systems);

    const magnitude: f32 = 100;

    for (set) |member| {
        var direction = ray.Vector2{ .x = 0, .y = 0 };

        if (keys.player_up.pressed()) {
            direction.y -= magnitude;
        }

        if (keys.player_down.pressed()) {
            direction.y += magnitude;
        }

        if (keys.player_left.pressed()) {
            direction.x -= magnitude;
        }

        if (keys.player_right.pressed()) {
            direction.x += magnitude;
        }

        var physics = self.get(Component.physics, member);
        physics.vel.x += direction.x * physics.acceleration * opt.dt;
        physics.vel.y += direction.y * physics.acceleration * opt.dt;
    }
}

pub fn updateDeathSystem(
    self: *ecs.ECS,
    a: std.mem.Allocator,
    opt: options.Update,
) void {
    const systems = [_]type{Component.health};
    const set = self.getSystemDomain(a, &systems);

    for (set) |member| {
        var health = self.get(Component.health, member);

        if (self.getMaybe(Component.health_trickle, member)) |health_trickle| {
            health.hp -= health_trickle.decrease_per_tick * opt.dt;
        }

        if (health.hp <= 0) {
            health.is_dead = true;
        }
        if (health.is_dead) {
            self.deleteEntity(a, member) catch return;
        }
    }
}

pub fn updateSpriteSystem(
    self: *ecs.ECS,
    a: std.mem.Allocator,
    animation_state: *anime.AnimationState,
    opt: options.Update,
) void {
    const systems = [_]type{Component.sprite};
    const set = self.getSystemDomain(a, &systems);

    for (set) |member| {
        self.components.sprite.get(member).?.player.update(animation_state, opt);
    }
}

//===============RENDERING================

fn tof32(input: anytype) f32 {
    return @floatFromInt(input);
}

pub inline fn scaleVector(a: ray.Vector2, scalar: anytype) ray.Vector2 {
    return .{ .x = a.x * tof32(scalar), .y = a.y * tof32(scalar) };
}

pub fn renderSprites(self: *ecs.ECS, a: std.mem.Allocator, animation_state: *const anime.AnimationState, tile_state: *const tile.TileState) void {
    const systems = [_]type{ Component.physics, Component.sprite };
    const set = self.getSystemDomain(a, &systems);

    for (set) |member| {
        const sprite = self.components.sprite.get(member).?;
        const physics = self.components.physics.get(member).?;

        sprite.player.render(animation_state, scaleVector(physics.pos, tile_state.resolution));
    }
}
