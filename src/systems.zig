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
const cam = @import("camera.zig");
pub const Component = @import("components.zig");
const intersection = @import("sparse_set.zig").intersection;
const ray = @cImport({
    @cInclude("raylib.h");
});

pub usingnamespace @import("movement.zig");
const moveTowards = @This().moveTowards;

//IMPORTANT, controls the scale of the position cache relative to the map
pub const position_cache_scale: usize = 2;

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

pub fn updatePlayerSystem(
    self: *ecs.ECS,
    a: std.mem.Allocator,
    keys: key.KeyBindings,
    camera: ray.Camera2D,
    tile_state_resolution: usize,
    opt: options.Update,
) void {
    const systems = [_]type{ Component.is_player, Component.physics };
    const set = self.getSystemDomain(a, &systems);

    const magnitude: f32 = 100;

    for (set) |member| {
        var direction = ray.Vector2{ .x = 0, .y = 0 };

        if (keys.player_up.down()) {
            direction.y -= magnitude;
        }

        if (keys.player_down.down()) {
            direction.y += magnitude;
        }

        if (keys.player_left.down()) {
            direction.x -= magnitude;
        }

        if (keys.player_right.down()) {
            direction.x += magnitude;
        }

        var physics = self.get(Component.physics, member);
        physics.vel.x += direction.x * physics.acceleration * opt.dt;
        physics.vel.y += direction.y * physics.acceleration * opt.dt;

        //let player shoot projectiles
        if (ray.IsMouseButtonDown(ray.MOUSE_BUTTON_LEFT)) {
            const fireball = self.newEntity(a) orelse return;
            const pos = cam.mousePos(camera, tile_state_resolution);
            self.addComponent(a, fireball, Component.physics{
                .pos = pos,
                .vel = .{
                    .x = (ecs.randomFloat() - 0.5) * opt.dt,
                    .y = (ecs.randomFloat() - 0.5) * opt.dt,
                },
            }) catch return;
            self.addComponent(a, fireball, Component.sprite{
                .player = .{ .animation_name = "fireball", .tint = ray.ColorAlpha(ray.ORANGE, 0.5) },
            }) catch return;
            self.addComponent(a, fireball, Component.damage{
                .type = "force",
                .amount = 10,
            }) catch return;
            self.addComponent(a, fireball, Component.hitbox{ .top = 0.1, .bottom = 0.1, .left = 0.1, .right = 0.1 }) catch return;
            self.addComponent(a, fireball, Component.health_trickle{ .decrease_per_tick = 0.001 }) catch return;
            self.addComponent(a, fireball, Component.health{ .hp = 1000 }) catch return;
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
        self.components.sprite.get(member).?.player.update(animation_state, opt);
    }
}

pub fn updateDamageSystem(
    self: *ecs.ECS,
    a: std.mem.Allocator,
    opt: options.Update,
) !void {
    _ = opt;
    const systems = [_]type{ Component.physics, Component.hitbox, Component.damage };
    const set = self.getSystemDomain(a, &systems);

    for (set) |member| {
        const colliders = try coll.findCollidingEntities(self, a, member);
        const damage = self.get(Component.damage, member);

        for (colliders) |entity| {
            var health = self.getMaybe(Component.health, entity) orelse continue;

            const animation = self.get(Component.sprite, entity).*.player.animation_name;
            std.debug.print("colliding entity found! {}{s}\n", .{ entity, animation });

            if (health.cooldown_remaining <= 0) {
                std.debug.print("damage dealt", .{});
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

        sprite.player.render(animation_state, scaleVector(physics.pos, tile_state.resolution));
    }
}
