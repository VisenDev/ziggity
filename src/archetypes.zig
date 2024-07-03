const std = @import("std");
const Component = @import("components.zig");
const options = @import("options.zig");
const ecs = @import("ecs.zig");

pub fn createSlime(self: *ecs.ECS, a: std.mem.Allocator) !usize {
    const id = self.newEntity(a) orelse return error.EntityCapReached;
    try self.setComponent(a, id, Component.Physics{});
    try self.setComponent(a, id, Component.Hitbox{});
    try self.setComponent(a, id, Component.Health{});
    try self.setComponent(a, id, Component.WallCollisions{});
    try self.setComponent(a, id, Component.EntityCollisions{});
    try self.setComponent(a, id, Component.Metadata{ .archetype = "slime" });
    try self.setComponent(a, id, Component.Sprite{ .animation_player = .{ .animation_name = "slime" }, .styling = .{ .bob = .{} } });
    try self.setComponent(a, id, Component.Controller{});
    try self.setComponent(a, id, Component.Wanderer{});
    try self.setComponent(a, id, Component.Light{});
    return id;
}

pub fn createPlayer(self: *ecs.ECS, a: std.mem.Allocator) !usize {
    const id = self.newEntity(a) orelse return error.EntityCapReached;
    try self.setComponent(a, id, Component.Physics{});
    try self.setComponent(a, id, Component.EntityCollisions{});
    try self.setComponent(a, id, Component.Hitbox{});
    try self.setComponent(a, id, Component.Health{});
    try self.setComponent(a, id, Component.WallCollisions{});
    try self.setComponent(a, id, Component.Inventory{});
    try self.setComponent(a, id, Component.Metadata{ .archetype = "player" });
    try self.setComponent(a, id, Component.Sprite{ .animation_player = .{ .animation_name = "player" }, .styling = .{ .lean = .{}, .bob = .{} } });
    try self.setComponent(a, id, Component.IsPlayer{});
    try self.setComponent(a, id, Component.MovementParticles{});
    try self.setComponent(a, id, Component.Light{ .radius_in_tiles = 3 });
    return id;
}

pub fn createFireball(self: *ecs.ECS, a: std.mem.Allocator) !usize {
    const id = self.newEntity(a) orelse return error.EntityCapReached;
    try self.setComponent(a, id, Component.Physics{});
    try self.setComponent(a, id, Component.Hitbox{ .bottom = 0.2, .left = 0.2 });
    try self.setComponent(a, id, Component.WallCollisions{});
    try self.setComponent(a, id, Component.Metadata{ .archetype = "projectile" });
    try self.setComponent(a, id, Component.Sprite{ .animation_player = .{ .animation_name = "fireball" } });
    try self.setComponent(a, id, Component.Damage{});
    try self.setComponent(a, id, Component.DieWithAnimation{});
    try self.setComponent(a, id, Component.Light{ .color = .{ .x = 0.5, .y = 0.1, .z = 0.1, .a = 0.9 }, .radius_in_tiles = 2 });
    return id;
}

pub fn createParticle(self: *ecs.ECS, a: std.mem.Allocator) !usize {
    const id = self.newEntity(a) orelse return error.EntityCapReached;
    try self.setComponent(a, id, Component.Physics{});
    try self.setComponent(a, id, Component.Sprite{ .animation_player = .{ .animation_name = "particle" }, .z_level = .background, .styling = .{
        .scale = .{},
    } });
    try self.setComponent(a, id, Component.Metadata{ .archetype = "particle" });
    try self.setComponent(a, id, Component.Lifetime{ .milliseconds_life_remaining = 5 * 1000 });
    return id;
}
