const std = @import("std");
const Component = @import("components.zig");
const options = @import("options.zig");
const ecs = @import("ecs.zig");

pub fn createSlime(self: *ecs.ECS, a: std.mem.Allocator) !usize {
    const id = self.newEntity(a) orelse return error.EntityCapReached;
    try self.setComponent(a, id, Component.physics{});
    try self.setComponent(a, id, Component.hitbox{});
    try self.setComponent(a, id, Component.wall_collisions{});
    try self.setComponent(a, id, Component.metadata{ .archetype = "slime" });
    try self.setComponent(a, id, Component.sprite{ .animation_player = .{ .animation_name = "slime" } });
    try self.setComponent(a, id, Component.controller{});
    try self.setComponent(a, id, Component.wanderer{});
    return id;
}
