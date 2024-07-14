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
    physics_1: Component.Physics,
    hitbox_1: Component.Hitbox,
    physics_2: Component.Physics,
    hitbox_2: Component.Hitbox,
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
    m: *const map.MapState,
    id: usize,
) ![]usize {
    self.collision_id_buffer.clearRetainingCapacity();

    const physics = self.getMaybe(Component.Physics, id) orelse return self.collision_id_buffer.items;
    const hitbox = self.getMaybe(Component.Hitbox, id) orelse return self.collision_id_buffer.items;

    const pos = physics.getCachePosition() orelse return self.collision_id_buffer.items;

    const nearby_cell_data = m.grid.findNearbyCells(pos.x, pos.y);
    for (nearby_cell_data) |maybe_cell_data| {
        if (maybe_cell_data) |cell_data| {
            for (cell_data.getCache()) |maybe_neighbor_id| {
                if (maybe_neighbor_id) |neighbor_id| {
                    if (neighbor_id == id) continue;

                    const neighbor_physics = self.getMaybe(Component.Physics, neighbor_id) orelse continue;
                    const neighbor_hitbox = self.getMaybe(Component.Hitbox, neighbor_id) orelse continue;

                    if (checkCollision(physics.*, hitbox.*, neighbor_physics.*, neighbor_hitbox.*)) {
                        try self.collision_id_buffer.append(a, neighbor_id);
                    }
                }
            }
        }
    }

    return self.collision_id_buffer.items;
}
