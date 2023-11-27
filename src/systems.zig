const std = @import("std");
const api = @import("api.zig");
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
const cam = @import("camera.zig");
const Lua = @import("ziglua").Lua;
pub const Component = @import("components.zig");
const intersection = @import("sparse_set.zig").intersection;
const ray = @cImport({
    @cInclude("raylib.h");
});

pub usingnamespace @import("movement.zig");
const moveTowards = @This().moveTowards;

//IMPORTANT, controls the scale of the position cache relative to the map
pub const position_cache_scale: usize = 1;

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
        const mind = self.get(Component.mind, member);
        const tracker = self.get(Component.mind, member);
        _ = tracker;

        switch (mind.activity) {}
    }
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
                const physics = self.get(Component.physics, member);
                moveTowards(physics, wanderer.destination, opt);
                wanderer.cooldown -= opt.dt;

                if (distance(physics.pos, wanderer.destination) < 1 or wanderer.cooldown <= 0) {
                    wanderer.state = .arrived;
                }
            },
        }
    }
}

pub fn updatePlayerSystem(
    self: *ecs.ECS,
    a: std.mem.Allocator,
    l: *Lua,
    keys: key.KeyBindings,
    camera: ray.Camera2D,
    tile_state_resolution: usize,
    opt: options.Update,
) !void {
    const systems = [_]type{ Component.is_player, Component.physics };
    const set = self.getSystemDomain(a, &systems);

    const magnitude: f32 = 100;

    for (set) |member| {
        var direction = ray.Vector2{ .x = 0, .y = 0 };

        if (keys.isDown("player_up")) {
            direction.y -= magnitude;
        }

        if (keys.isDown("player_down")) {
            direction.y += magnitude;
        }

        if (keys.isDown("player_left")) {
            direction.x -= magnitude;
        }

        if (keys.isDown("player_right")) {
            direction.x += magnitude;
        }

        var physics = self.get(Component.physics, member);
        physics.vel.x += direction.x * physics.acceleration * opt.dt;
        physics.vel.y += direction.y * physics.acceleration * opt.dt;

        //let player shoot projectiles
        if (ray.IsMouseButtonDown(ray.MOUSE_BUTTON_LEFT)) {
            const fireball = api.call(l, "SpawnFireball") catch break;
            const pos = cam.mousePos(camera, tile_state_resolution);
            self.setComponent(a, fireball, Component.physics{
                .pos = pos,
                .vel = .{
                    .x = (ecs.randomFloat() - 0.5) * opt.dt,
                    .y = (ecs.randomFloat() - 0.5) * opt.dt,
                },
            }) catch |err| std.debug.print("error adding component to entity when spawning fireball {!}", .{err});
        }

        //spawnSlimes
        if (ray.IsMouseButtonDown(ray.MOUSE_BUTTON_RIGHT)) {
            const slime = api.call(l, "SpawnSlime") catch break;
            const pos = cam.mousePos(camera, tile_state_resolution);
            self.setComponent(a, slime, Component.physics{
                .pos = pos,
            }) catch unreachable;
        }
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

pub fn updateHealthCooldownSystem(
    self: *ecs.ECS,
    a: std.mem.Allocator,
    opt: options.Update,
) void {
    const systems = [_]type{Component.health};
    const set = self.getSystemDomain(a, &systems);

    for (set) |member| {
        var health = self.get(Component.health, member);

        if (health.cooldown_remaining >= 0) {
            health.cooldown_remaining -= opt.dt;
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
        const sprite_maybe = self.getMaybe(Component.sprite, member);
        if (sprite_maybe) |sprite| {
            sprite.animation_player.update(animation_state, opt);
        } else {
            std.debug.print("{} id has flags {b}", .{ member, self.bitflags.get(member).?.*.mask });
            @panic("Get system domain failed");
        }
    }
}

pub fn updateDamageSystem(
    self: *ecs.ECS,
    a: std.mem.Allocator,
    opt: options.Update,
) !void {
    _ = opt;
    const systems = [_]type{ Component.hitbox, Component.damage, Component.physics };
    const set = self.getSystemDomain(a, &systems);

    for (set) |member| {
        const damage = self.get(Component.damage, member);

        const colliders = try coll.findCollidingEntities(self, a, member);
        for (colliders) |entity| {
            if (self.getMaybe(Component.invulnerable, entity)) |_| continue;
            var health = self.getMaybe(Component.health, entity) orelse continue;

            if (health.cooldown_remaining <= 0) {
                health.hp -= damage.amount;
                health.cooldown_remaining = Component.health.damage_cooldown;
            }
        }
    }
}

//===============RENDERING================

pub fn tof32(input: anytype) f32 {
    return @floatFromInt(input);
}

pub inline fn scaleVector(a: ray.Vector2, scalar: anytype) ray.Vector2 {
    if (@TypeOf(scalar) == f32)
        return .{ .x = a.x * scalar, .y = a.y * scalar };

    return .{ .x = a.x * tof32(scalar), .y = a.y * tof32(scalar) };
}

pub inline fn scaleRectangle(a: ray.Rectangle, scalar: anytype) ray.Rectangle {
    if (@TypeOf(scalar) == f32)
        return .{ .x = a.x * scalar, .y = a.y * scalar, .width = a.width * scalar, .height = a.height * scalar };

    const floated = tof32(scalar);
    return .{ .x = a.x * floated, .y = a.y * floated, .width = a.width * floated, .height = a.height * floated };
}

pub fn renderSprites(self: *ecs.ECS, a: std.mem.Allocator, animation_state: *const anime.AnimationState, tile_state: *const tile.TileState) void {
    const systems = [_]type{ Component.physics, Component.sprite };
    const set = self.getSystemDomain(a, &systems);

    for (set) |member| {
        const sprite = self.components.sprite.get(member).?;
        const physics = self.components.physics.get(member).?;

        sprite.animation_player.render(animation_state, scaleVector(physics.pos, tile_state.resolution));
    }
}
