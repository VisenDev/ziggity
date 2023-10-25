const std = @import("std");
const anime = @import("animation.zig");
const map = @import("map.zig");
const texture = @import("textures.zig");
const key = @import("keybindings.zig");
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

pub fn updateMovementSystem(
    self: *ecs.ECS,
    a: std.mem.Allocator,
    m: *const map.MapState,
    textures: *const texture.TextureState,
    opt: options.Update,
) void {
    _ = textures;
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
        if (self.getMaybe(Component.collider, member)) |collider| {
            if (checkCollision(physics.pos, collider, &m.collision_grid)) {
                physics.pos = old_position;
            }
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
pub fn renderSprites(self: *ecs.ECS, a: std.mem.Allocator, animation_state: *const anime.AnimationState, opt: options.Render) void {
    const systems = [_]type{ Component.physics, Component.sprite };
    const set = self.getSystemDomain(a, &systems);

    for (set) |member| {
        const sprite = self.components.sprite.get(member).?;
        const physics = self.components.physics.get(member).?;

        const screen_position = ray.Rectangle{
            .x = physics.pos.x * opt.grid_spacing,
            .y = physics.pos.y * opt.grid_spacing,
            .width = opt.grid_spacing,
            .height = opt.grid_spacing,
        };
        sprite.player.render(animation_state, screen_position);
    }
}
