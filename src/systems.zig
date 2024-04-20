const std = @import("std");
const camera = @import("camera.zig");
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

//pub usingnamespace @import("movement.zig");
const moveTowards = @This().moveTowards;

//IMPORTANT, controls the scale of the position cache relative to the map
pub const position_cache_scale: usize = 1;

fn distance(a: ray.Vector2, b: ray.Vector2) f32 {
    const dx = a.x - b.x;
    const dy = a.y - b.y;

    return @sqrt(dx * dx + dy * dy);
}

pub fn updateDeathSystem(
    self: *ecs.ECS,
    a: std.mem.Allocator,
    l: *Lua,
    opt: options.Update,
) !void {
    const systems = [_]type{Component.Health};
    const set = self.getSystemDomain(a, &systems);

    for (set) |member| {
        var health = self.get(Component.Health, member);

        if (self.getMaybe(Component.HealthTrickle, member)) |health_trickle| {
            health.hp -= health_trickle.decrease_per_tick * opt.dt;
        }

        if (health.hp <= 0) {
            health.is_dead = true;

            if (self.getMaybe(Component.Loot, member)) |loot| {
                const physics = self.getMaybe(Component.Physics, member) orelse continue;
                for (loot.items) |item_script| {
                    var copy = a;
                    const item = try l.autoCall(?usize, item_script, .{ self, &copy }) orelse continue;
                    try self.setComponent(a, item, Component.Physics{
                        .pos = .{
                            .x = physics.pos.x + 0.3 + 0.2 * (ecs.randomFloat() - 0.5),
                            .y = physics.pos.y + 0.8 * (ecs.randomFloat() - 0.5),
                        },
                    });
                }
            }

            if (self.getMaybe(Component.DeathParticles, member)) |particle| {
                _ = particle;
                const physics = self.get(Component.Physics, member);
                for (0..5) |_| {
                    var copy = a;
                    const blood = try l.autoCall(?usize, "SpawnBloodParticle", .{ self, &copy }) orelse continue;
                    try self.setComponent(a, blood, Component.Physics{
                        .pos = .{
                            .x = physics.pos.x + 0.3 + 0.2 * (ecs.randomFloat() - 0.5),
                            .y = physics.pos.y + 0.8 * (ecs.randomFloat() - 0.5),
                        },
                    });
                }
            }

            if (self.getMaybe(Component.DeathAnimation, member)) |animation| {
                const physics = self.getMaybe(Component.Physics, member) orelse continue;
                //const death_animation_entity = api.call(l, "SpawnAnimation") catch continue;
                var copy = a;
                const death_animation_entity = try l.autoCall(?usize, "SpawnAnimation", .{ self, &copy }) orelse continue;
                try self.setComponent(a, death_animation_entity, Component.Physics{
                    .pos = .{
                        .x = physics.pos.x + 0.3 + 0.2 * (ecs.randomFloat() - 0.5),
                        .y = physics.pos.y + 0.8 * (ecs.randomFloat() - 0.5),
                    },
                });
                try self.setComponent(a, death_animation_entity, Component.Sprite{
                    .animation_player = .{ .animation_name = try a.dupeZ(u8, animation.animation_name) },
                });
            }
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
    const systems = [_]type{Component.Health};
    const set = self.getSystemDomain(a, &systems);

    for (set) |member| {
        var health = self.get(Component.Health, member);

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
    const systems = [_]type{Component.Sprite};
    const set = self.getSystemDomain(a, &systems);

    for (set) |member| {
        const sprite_maybe = self.getMaybe(Component.Sprite, member);
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
    const systems = [_]type{ Component.Hitbox, Component.Damage, Component.Physics };
    const set = self.getSystemDomain(a, &systems);

    for (set) |member| {
        const damage = self.get(Component.Damage, member);

        const colliders = try coll.findCollidingEntities(self, a, member);
        for (colliders) |entity| {
            if (self.getMaybe(Component.Invulnerable, entity)) |_| continue;
            var health = self.getMaybe(Component.Health, entity) orelse continue;

            if (health.cooldown_remaining <= 0) {
                health.hp -= damage.amount;
                health.cooldown_remaining = Component.Health.damage_cooldown;
            }
        }
    }
}

pub fn trimAnimationEntitySystem(
    self: *ecs.ECS,
    a: std.mem.Allocator,
    opt: options.Update,
) !void {
    _ = opt;
    const systems = [_]type{ Component.DieWithAnimation, Component.Sprite };
    const set = self.getSystemDomain(a, &systems);

    for (set) |member| {
        const sprite = self.get(Component.Sprite, member);
        if (sprite.animation_player.disabled) {
            try self.deleteEntity(a, member);
        }
    }
}
