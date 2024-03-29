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
    try self.setComponent(a, id, Component.Metadata{ .archetype = "slime" });
    try self.setComponent(a, id, Component.Sprite{ .animation_player = .{ .animation_name = "slime" } });
    try self.setComponent(a, id, Component.Controller{});
    try self.setComponent(a, id, Component.Wanderer{});
    return id;
}

pub fn createPlayer(self: *ecs.ECS, a: std.mem.Allocator) !usize {
    const id = self.newEntity(a) orelse return error.EntityCapReached;
    try self.setComponent(a, id, Component.Physics{});
    try self.setComponent(a, id, Component.Hitbox{});
    try self.setComponent(a, id, Component.Health{});
    try self.setComponent(a, id, Component.WallCollisions{});
    try self.setComponent(a, id, Component.Metadata{ .archetype = "player" });
    try self.setComponent(a, id, Component.Sprite{ .animation_player = .{ .animation_name = "player" } });
    try self.setComponent(a, id, Component.IsPlayer{});
    return id;
}

pub fn createFireball(self: *ecs.ECS, a: std.mem.Allocator) !usize {
    const id = self.newEntity(a) orelse return error.EntityCapReached;
    try self.setComponent(a, id, Component.Physics{});
    try self.setComponent(a, id, Component.Hitbox{});
    try self.setComponent(a, id, Component.WallCollisions{});
    try self.setComponent(a, id, Component.Metadata{ .archetype = "projectile" });
    try self.setComponent(a, id, Component.Sprite{ .animation_player = .{ .animation_name = "fireball" } });
    try self.setComponent(a, id, Component.Damage{});
    return id;
}
