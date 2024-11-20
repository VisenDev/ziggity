const anime = @import("animation.zig");
const arch = @import("archetypes.zig");
const move = @import("movement.zig");
const std = @import("std");
const light = @import("light.zig");
const ai = @import("ai.zig");
const inv = @import("inventory.zig");
const Component = @import("components.zig");
const control = @import("controller.zig");
const sys = @import("systems.zig");
const options = @import("options.zig");
const ECS = @import("ecs.zig").ECS;

const dvui = @import("dvui");
const ray = @import("raylib-import.zig").ray;

pub const FireballWand = struct {
    pub fn create(self: *ECS, a: std.mem.Allocator) !usize {
        const id = self.newEntity(a) orelse return error.EntityCapReached;
        try self.setComponent(a, id, Component.Physics{});
        try self.setComponent(a, id, Component.Hitbox{});
        try self.setComponent(a, id, Component.WallCollisions{});
        try self.setComponent(a, id, Component.Item{
            .animation_player = .{ .animation_name = "fireball_wand" },
            .type_of_item = "fireball wand",
            .tick_fn = "FireballWand",
        });
        try self.setComponent(a, id, Component.Metadata{ .archetype = "item" });
        //try self.setComponent(a, id, Component.Light{ .color = .{ .x = 0.5, .y = 0.1, .z = 0.1, .a = 0.9 }, .radius_in_tiles = 0.5 });
        return id;
    }

    pub fn tick(a: std.mem.Allocator, item_id: usize, ecs: *ECS, wm: *anime.WindowManager, opt: options.Update) !void {
        if (wm.getMouseOwner() == .level and wm.isMousePressed(.left) and wm.getPlayerHeldItem(a, ecs) == item_id) {
            const systems = [_]type{ Component.IsPlayer, Component.Physics };
            const set = ecs.getSystemDomain(a, &systems);
            const player = set[0];

            const physics = ecs.get(Component.Physics, player);
            const mouse_pos = wm.getMouseTileCoordinates();

            const angle = move.getAngleBetween(physics.position, mouse_pos);

            var fireball_physics: Component.Physics = .{
                .position = .{ .x = physics.position.x, .y = physics.position.y },
                .mass = 0.001,
                .coefficient_of_friction = 0,
            };
            const base_force: ray.Vector2 = .{ .x = 2, .y = 0 };
            fireball_physics.applyForce(move.rotateVector2(base_force, angle, .{ .x = 0, .y = 0 }));

            const fireball_id = try arch.createFireball(ecs, a);
            try ecs.setComponent(a, fireball_id, fireball_physics);
            try ecs.setComponent(a, fireball_id, Component.Damage{
                .type = "fire",
                .amount = 10,
                .ignore_entities = try a.dupe(usize, &.{player}),
            });
        }

        _ = opt; // autofix
    }
};

pub const ItemWand = struct {
    pub fn create(self: *ECS, a: std.mem.Allocator) !usize {
        const id = self.newEntity(a) orelse return error.EntityCapReached;
        try self.setComponent(a, id, Component.Physics{});
        try self.setComponent(a, id, Component.Hitbox{});
        try self.setComponent(a, id, Component.WallCollisions{});
        try self.setComponent(a, id, Component.Item{
            .animation_player = .{ .animation_name = "item_wand" },
            .type_of_item = "item wand",
            .tick_fn = "ItemWand",
        });
        try self.setComponent(a, id, Component.Metadata{ .archetype = "item" });
        //try self.setComponent(a, id, Component.Light{ .color = .{ .x = 0.5, .y = 0.1, .z = 0.1, .a = 0.9 }, .radius_in_tiles = 0.5 });
        return id;
    }

    pub fn tick(a: std.mem.Allocator, item_id: usize, ecs: *ECS, wm: *anime.WindowManager, opt: options.Update) !void {
        _ = opt; // autofix
        if (wm.getMouseOwner() == .level and wm.isMousePressed(.left) and wm.getPlayerHeldItem(a, ecs) == item_id) {
            const mouse_pos = wm.getMouseTileCoordinates();

            const physics: Component.Physics = .{
                .position = .{ .x = mouse_pos.x, .y = mouse_pos.y },
            };
            const id = try Potion.create(ecs, a);
            try ecs.setComponent(a, id, physics);
        }
    }
};

pub const SlimeWand = struct {
    pub fn create(self: *ECS, a: std.mem.Allocator) !usize {
        const id = self.newEntity(a) orelse return error.EntityCapReached;
        try self.setComponent(a, id, Component.Physics{});
        try self.setComponent(a, id, Component.Hitbox{});
        try self.setComponent(a, id, Component.WallCollisions{});
        try self.setComponent(a, id, Component.Item{
            .animation_player = .{ .animation_name = "slime_wand" },
            .type_of_item = "slime wand",
            .tick_fn = "SlimeWand",
        });
        try self.setComponent(a, id, Component.Metadata{ .archetype = "item" });
        //try self.setComponent(a, id, Component.Light{ .color = .{ .x = 0.5, .y = 0.1, .z = 0.1, .a = 0.9 }, .radius_in_tiles = 0.5 });
        return id;
    }

    pub fn tick(a: std.mem.Allocator, item_id: usize, ecs: *ECS, wm: *anime.WindowManager, opt: options.Update) !void {
        _ = opt; // autofix
        if (wm.getMouseOwner() == .level and wm.isMousePressed(.left) and wm.getPlayerHeldItem(a, ecs) == item_id) {
            const mouse_pos = wm.getMouseTileCoordinates();

            const physics: Component.Physics = .{
                .position = .{ .x = mouse_pos.x, .y = mouse_pos.y },
            };
            const id = try arch.createSlime(ecs, a);
            try ecs.setComponent(a, id, physics);
        }
    }
};

pub const Potion = struct {
    pub fn create(self: *ECS, a: std.mem.Allocator) !usize {
        const id = self.newEntity(a) orelse return error.EntityCapReached;
        try self.setComponent(a, id, Component.Physics{});
        try self.setComponent(a, id, Component.Hitbox{});
        try self.setComponent(a, id, Component.WallCollisions{});
        try self.setComponent(a, id, Component.Item{
            .animation_player = .{ .animation_name = "potion" },
            .type_of_item = "potion",
            .tick_fn = "Potion",
        });
        try self.setComponent(a, id, Component.Metadata{ .archetype = "item" });
        //try self.setComponent(a, id, Component.Light{ .color = .{ .x = 0.5, .y = 0.1, .z = 0.1, .a = 0.9 }, .radius_in_tiles = 0.5 });
        return id;
    }

    pub fn tick(a: std.mem.Allocator, item_id: usize, ecs: *ECS, wm: *anime.WindowManager, opt: options.Update) !void {
        _ = a; // autofix
        _ = item_id; // autofix
        _ = ecs; // autofix
        _ = wm; // autofix
        _ = opt; // autofix
    }
};
