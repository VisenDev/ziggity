const std = @import("std");
const map = @import("map.zig");
const key = @import("keybindings.zig");
const texture = @import("textures.zig");
const options = @import("options.zig");
const SparseSet = @import("sparse_set.zig").SparseSet;
const Grid = @import("grid.zig").Grid;
pub const Component = @import("components.zig");
const ecs = @import("ecs.zig");
const ray = @cImport({
    @cInclude("raylib.h");
});

pub fn checkCollision(
    physics_1: Component.physics,
    hitbox_1: Component.hitbox,
    physics_2: Component.physics,
    hitbox_2: Component.hitbox,
) bool {
    return ray.CheckCollisionRecs(
        hitbox_1.getCollisionRect(physics_1.pos),
        hitbox_2.getCollisionRect(physics_2.pos),
    );
}

///Beware: This function changes the contents of collision_id_buffer
pub fn findCollidingEntities(
    self: *ecs.ECS,
    a: std.mem.Allocator,
    id: usize,
) ![]usize {
    self.collision_id_buffer.clearRetainingCapacity();

    const physics = self.getMaybe(Component.physics, id) orelse return self.collision_id_buffer.items;
    const hitbox = self.getMaybe(Component.hitbox, id) orelse return self.collision_id_buffer.items;

    const pos = physics.getCachePosition();
    const neighbor_list = self.position_cache.findNeighbors(a, pos.x, pos.y);
    for (neighbor_list) |neighbor| {
        for (neighbor.items) |neighbor_id| {
            const neighbor_physics = self.getMaybe(Component.physics, neighbor_id) orelse continue;
            const neighbor_hitbox = self.getMaybe(Component.hitbox, neighbor_id) orelse continue;

            if (checkCollision(physics.*, hitbox.*, neighbor_physics.*, neighbor_hitbox.*)) {
                try self.collision_id_buffer.append(a, neighbor_id);
            }
        }
    }

    return self.collision_id_buffer.items;
}
