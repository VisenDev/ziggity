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

const raygui = @cImport({
    @cInclude("raygui.h");
    @cInclude("style_dark.h");
});

const eql = std.mem.eql;

// =========Component types=========
pub const ItemComponent = struct {
    pub const name = "item";
    type: [:0]const u8 = "unknown",
    stack_size: usize = 1,
    max_stack_size: usize = 99,
    item_cooldown_ms: ?f32 = null,
};

//pub const InventorySlot = struct {
//    item_count: usize = 1,
//    item_id: usize = 0,
//};

pub fn Inventory(comptime width: usize, comptime height: usize, comptime internal_name: []const u8) type {
    return struct {
        const Self = @This();

        /// Index struct
        pub const Index = struct {
            x: usize = 0,
            y: usize = 0,

            pub fn isAtStartingIndex(self: @This()) bool {
                return self == @This(){};
            }

            ///returns true f incrementation has reset to the beginning
            pub fn increment(self: *@This()) bool {
                self.x += 1;
                if (self.x >= width) {
                    self.x = 0;
                    self.y += 1;

                    if (self.y >= height) {
                        self.y = 0;
                        self.x = 0;
                        return false;
                    }
                }
                return true;
            }
        };

        pub const ItemId = ?usize;

        pub const Iterator = struct {
            inventory_ptr: *Self,
            index: Index = .{},
            pub fn next(self: *@This()) ?Index {
                const result = self.index;
                if (self.index.increment()) {
                    return null;
                }
                return result;
            }
        };

        pub const name = internal_name;
        item_ids: [width][height]ItemId = .{.{null} ** width} ** height,
        selected_index: Index = .{},

        pub fn getIndex(self: *const @This(), index: Index) ItemId {
            return self.item_ids[index.x][index.y];
        }

        pub fn getSelectedItemId(self: *const @This()) ItemId {
            return self.getIndex(self.selected_index);
        }

        pub fn findFirstEmptySlot(self: *@This()) ?Index {
            var iterator = self.iterate();
            while (iterator.next()) |index| {
                if (self.getIndex(index) == null) {
                    return index;
                }
            }
            return null;
        }

        /// transfers item to first available index in inventory
        pub fn pickupItem(self: *@This(), item_id: usize) !void {
            const maybe_index = self.findFirstEmptySlot();
            if (maybe_index) |index| {
                self.item_ids[index.x][index.y] = item_id;
            } else {
                return error.OutOfSpace;
            }
        }

        pub fn iterate(self: *@This()) Iterator {
            return Iterator{ .inventory_ptr = self };
        }

        pub const InventoryRenderOptions = struct {
            pub const Corner = enum { top_left, top_right, bottom_left, bottom_right, center_point };
            position: ray.Vector2,
            which_corner: Corner = .center_point,
        };

        pub const default_slot_render_size = 32;

        fn calculateRenderedWidth(self: *const @This(), animation_state: *const anime.AnimationState) f32 {
            // TODO account for UI scaling
            _ = self;
            _ = animation_state;
            return width * default_slot_render_size;
        }

        fn calculateRenderedHeight(self: *const @This(), animation_state: *const anime.AnimationState) f32 {
            // TODO account for UI scaling
            _ = self;
            _ = animation_state;
            return height * default_slot_render_size;
        }

        pub fn render(self: *@This(), animation_state: *const anime.AnimationState, render_opt: InventoryRenderOptions) bool {
            const render_width = self.calculateRenderedWidth(animation_state);
            const render_height = self.calculateRenderedHeight(animation_state);
            const render_position: ray.Vector2 = switch (render_opt.which_corner) {
                .center_point => .{ .x = render_opt.position.x - (render_width / 2), .y = render_opt.position.y - (render_height / 2) },
                .top_left => render_opt.position,
                else => @panic("not implemented yet"),
            };
            const close_inventory = raygui.GuiWindowBox(.{
                .x = render_position.x,
                .y = render_position.y,
                .width = render_width,
                .height = render_height,
            }, "Inventory");

            var iterator = self.iterate();
            while (iterator.next()) |index| {
                _ = index.x;
            }
            return close_inventory == 1;
        }
    };
}

pub const InventoryComponent = Inventory(4, 4, "Inventory");

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

        for (colliders) |entity| {
            if (self.hasComponent(Component.Item, entity)) {
                inventory.pickupItem(entity) catch continue;
                try self.deleteComponent(entity, Component.Physics);
            }
        }
    }
}

pub fn renderPlayerInventory(
    self: *ecs.ECS,
    a: std.mem.Allocator,
    animation_state: *anime.AnimationState,
) void {
    const systems = [_]type{ Component.IsPlayer, Component.Inventory };
    const set = self.getSystemDomain(a, &systems);

    for (set) |member| {
        const inventory = self.get(Component.Inventory, member);
        _ = inventory.render(animation_state, .{ .position = .{ .x = anime.screenWidth() / 2, .y = anime.screenHeight() / 2 } });
        //for (0..inventory.len) |i| {
        //    //_ = std.fmt.bufPrintZ(&buf, "{} entities", .{inventory.slots()[i].item_count}) catch unreachable;
        //    const y: c_int = @intCast(i * 20);
        //    const item = self.get(Component.Item, inventory.slots()[i].id);
        //    ray.DrawText(item.type.ptr, 200, 25 + y, 15, ray.RAYWHITE);

        //    var buf: [1024:0]u8 = undefined;
        //    _ = std.fmt.bufPrintZ(&buf, "{}", .{inventory.slots()[i].item_count}) catch unreachable;
        //    ray.DrawText(&buf, 170, 25 + y, 15, ray.RAYWHITE);
        //}
    }
}
//const inventory self.get(Component.Inventory, )
