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

const eql = std.mem.eql;

// =========Component types=========
pub const ItemComponent = struct {
    pub const name = "item";
    type: [:0]const u8 = "unknown",
    max_stack_size: usize = 99,
    status: enum { in_inventory, in_world } = .in_world,
};

pub const InventoryComponent = struct {
    pub const name = "inventory";
    const max_cap = 256;
    const Slot = struct {
        item_count: usize = 1,
        id: usize = 0,
    };
    buffer: [max_cap]Slot = [_]Slot{.{}} ** max_cap,

    len: usize = 0,
    capacity: usize = 64,
    selected_index: usize = 0,

    pub inline fn slots(self: *@This()) []Slot {
        return self.buffer[0..self.len];
    }
};

////======normal code=========

fn findExistingSlot(self: *const ecs.ECS, inv: *Component.Inventory, item: Component.Item) ?usize {
    if (item.max_stack_size == 1) {
        return null;
    }

    for (inv.slots(), 0..) |slot, i| {
        const inv_item = self.get(Component.Item, slot.id);
        if (std.mem.eql(u8, item.type, inv_item.type) and slot.item_count < item.max_stack_size and item.max_stack_size == inv_item.max_stack_size) {
            return i;
        }
    }
    return null;
}

pub fn addItem(self: *ecs.ECS, a: std.mem.Allocator, inv: *Component.Inventory, new_item_id: usize) !void {
    const new_item = self.getMaybe(Component.Item, new_item_id) orelse return error.id_missing_item_component;

    if (findExistingSlot(self, inv, new_item.*)) |index| {
        inv.slots()[index].item_count += 1;
        try self.deleteEntity(a, new_item_id);
    } else {
        inv.buffer[inv.len] = .{
            .id = new_item_id,
        };
        inv.len += 1;
        self.get(Component.Item, new_item_id).status = .in_inventory;
    }
}

pub fn updateInventorySystem(
    self: *ecs.ECS,
    a: std.mem.Allocator,
    opt: options.Update,
) !void {
    _ = opt;
    const systems = [_]type{ Component.Inventory, Component.Hitbox };
    const set = self.getSystemDomain(a, &systems);

    for (set) |member| {
        const colliders = try coll.findCollidingEntities(self, a, member);

        var inventory = self.get(Component.Inventory, member);
        _ = &inventory;
        if (inventory.len >= inventory.capacity) {
            continue;
        }

        for (colliders) |entity| {
            if (self.getMaybe(Component.Item, entity)) |item| {
                if (item.status == .in_world) {
                    addItem(self, a, inventory, entity) catch break;
                    break;
                }
            }
        }
    }
}

pub fn renderPlayerInventory(
    self: *ecs.ECS,
    a: std.mem.Allocator,
    animation_state: *const anime.AnimationState,
) void {
    const systems = [_]type{ Component.IsPlayer, Component.Inventory };
    const set = self.getSystemDomain(a, &systems);
    _ = animation_state;

    for (set) |member| {
        const inventory = self.get(Component.Inventory, member);
        for (0..inventory.len) |i| {
            //_ = std.fmt.bufPrintZ(&buf, "{} entities", .{inventory.slots()[i].item_count}) catch unreachable;
            const y: c_int = @intCast(i * 20);
            const item = self.get(Component.Item, inventory.slots()[i].id);
            ray.DrawText(item.type.ptr, 200, 25 + y, 15, ray.RAYWHITE);

            var buf: [1024:0]u8 = undefined;
            _ = std.fmt.bufPrintZ(&buf, "{}", .{inventory.slots()[i].item_count}) catch unreachable;
            ray.DrawText(&buf, 170, 25 + y, 15, ray.RAYWHITE);
        }
    }
}
//const inventory self.get(Component.Inventory, )
