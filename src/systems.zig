const std = @import("std");
const map = @import("map.zig");
const config = @import("config.zig");
const texture = @import("textures.zig");
const options = @import("options.zig");
const ecs = @import("ecs.zig");
const SparseSet = @import("sparse_set.zig").SparseSet;
pub const Component = @import("components.zig");
const intersection = @import("sparse_set.zig").intersection;
const ray = @cImport({
    @cInclude("raylib.h");
});

pub fn checkCollision(
    position: ray.Vector2,
    collider: *const Component.collider,
    collision_grid: *const map.Grid(bool),
) bool {
    _ = collision_grid;
    _ = collider;
    _ = position;
    return false;
}

fn distance(a: ray.Vector2, b: ray.Vector2) f32 {
    const dx = a.x - b.x;
    const dy = a.y - b.y;

    return @sqrt(dx * dx + dy * dy);
}

pub fn updateHostileAiSystem(self: *ecs.ECS, a: std.mem.Allocator, opt: options.Update) void {
    _ = opt;

    const systems = [_]type{ Component.mind, Component.tracker };
    const set = self.getSystemDomain(a, &systems);
    defer set.deinit();

    for (set.items) |member| {
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
    const systems = [_]type{ Component.wanderer, Component.physics };
    const set = self.getSystemDomain(a, &systems);
    defer set.deinit();

    for (set.items) |member| {
        var wanderer = self.get(Component.wanderer, member);

        switch (wanderer.state) {
            .arrived => {
                wanderer.cooldown = opt.dt * 300;
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
            },
            .travelling => {
                var physics = self.get(Component.physics, member);
                moveTowards(physics, wanderer.destination, opt);

                if (distance(physics.pos, wanderer.destination) < 1) {
                    wanderer.state = .arrived;
                }
            },
        }
    }
}

pub fn updateMovementSystem(self: *ecs.ECS, a: std.mem.Allocator, m: *const map.MapState, opt: options.Update) void {
    _ = opt;

    const set = self.getSystemDomain(a, &[_]type{Component.physics});
    defer set.deinit();

    for (set.items) |member| {
        var physics = self.get(Component.physics, member);

        const old_position = physics.pos;

        physics.pos.x += physics.vel.x;
        physics.pos.y += physics.vel.y;

        physics.vel.x *= physics.friction;
        physics.vel.y *= physics.friction;

        //undo if the entity collides
        if (self.getMaybe(Component.collider, member)) |collider| {
            if (checkCollision(physics.pos, collider, &m.collision_grid)) {
                physics.pos = old_position;
            }
        }
    }
}

pub fn updatePlayerSystem(
    self: *ecs.ECS,
    a: std.mem.Allocator,
    keys: config.KeyBindings,
    opt: options.Update,
) void {
    const systems = [_]type{ Component.is_player, Component.physics };
    const set = self.getSystemDomain(a, &systems);
    defer set.deinit();

    const magnitude: f32 = 100;

    for (set.items) |member| {
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
