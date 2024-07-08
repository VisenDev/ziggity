const std = @import("std");
const arch = @import("archetypes.zig");
const api = @import("api.zig");
const tile = @import("tiles.zig");
const anime = @import("animation.zig");
const map = @import("map.zig");
const texture = @import("textures.zig");
const key = @import("keybindings.zig");
const options = @import("options.zig");
const ECS = @import("ecs.zig").ECS;
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
    type_of_item: [:0]const u8 = "unknown",
    category_of_item: [:0]const u8 = "unknown",
    stack_size: usize = 1,
    max_stack_size: usize = 99,
    item_cooldown_ms: ?f32 = null,
    animation_player: anime.AnimationPlayer = .{ .animation_name = "potion" },

    pub fn renderInUi(self: *const @This(), window_manager: *const anime.WindowManager, screen_position: ray.Vector2) void {
        self.animation_player.renderOnScreen(window_manager, screen_position, .{});
    }

    pub fn renderInWorld(self: *const @This(), window_manager: *const anime.WindowManager, tile_coordinates: ray.Vector2) void {
        self.animation_player.renderInWorld(window_manager, tile_coordinates, .{});
    }

    pub fn isSameTypeAs(self: *const @This(), other_item: *const @This()) bool {
        return std.mem.eql(u8, self.type_of_item, other_item.type_of_item);
    }

    pub fn capacityRemaining(self: *const @This()) usize {
        return self.max_stack_size - self.stack_size;
    }
};

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

            pub fn vector2(self: @This()) ray.Vector2 {
                return .{ .x = @floatFromInt(self.x), .y = @floatFromInt(self.y) };
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
                        return true;
                    }
                }
                return false;
            }
        };

        pub const ItemId = ?usize;

        pub const Iterator = struct {
            inventory_ptr: *const Self,
            index: Index = .{},
            iteration_complete: bool = false,
            pub fn next(self: *@This()) ?Index {
                if (self.iteration_complete) {
                    return null;
                }

                const result = self.index;
                self.iteration_complete = self.index.increment();
                return result;
            }
        };

        pub const ItemIterator = struct {
            ecs_ptr: *const ECS,
            iterator: Iterator,
            last_item_index: ?Index = null,
            pub fn next(self: *@This()) ?ItemComponent {
                const index = self.iterator.next();
                if (index == null) return null;

                const item_id = self.iterator.inventory_ptr.getIndex(index.?);
                if (item_id == null) return self.next();

                self.last_item_index = index;
                return self.ecs_ptr.get(Component.ItemComponent, item_id.?);
            }

            pub fn getIndexOfLastItem(self: @This()) ?Index {
                return self.last_item_index;
            }
        };

        pub const name = internal_name;
        item_ids: [width][height]ItemId = .{.{null} ** width} ** height,
        selected_index: Index = .{},
        default_slot_render_size: f32 = 32,
        wants_to_close: bool = false,
        state: enum { visible_focused, visible, hidden } = .hidden,

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

        const SearchType = union(enum) {
            find_empty_slot: void,
            find_slot_for_stacking: struct {
                //item_to_match: ItemComponent,
                item_id_to_match: usize,
            },
            find_slot_same_type: struct {
                //item_to_match: ItemComponent,
                item_id_to_match: usize,
            },

            pub fn getIdToMatch(self: @This()) ?usize {
                switch (self) {
                    .find_empty_slot => return null,
                    .find_slot_same_type => |find| return find.item_id_to_match,
                    .find_slot_for_stacking => |find| return find.item_id_to_match,
                }
            }
        };

        pub fn findSlot(self: *const @This(), ecs: *const ECS, search_type: SearchType) ?Index {
            var iterator = self.iterate();
            const match_item_id = search_type.getIdToMatch();
            const match_item = if (match_item_id == null) null else ecs.get(Component.Item, match_item_id.?);

            while (iterator.next()) |index| {
                const slot_item_id = self.getIndex(index);
                switch (search_type) {
                    .find_empty_slot => {
                        if (slot_item_id == null) {
                            return index;
                        }
                    },
                    .find_slot_same_type => {
                        const slot_item = ecs.get(Component.Item, slot_item_id.?);
                        if (slot_item.isSameTypeAs(match_item.?)) return index;
                    },
                    .find_slot_for_stacking => {
                        const slot_item = ecs.get(Component.Item, slot_item_id.?);
                        if (slot_item.isSameTypeAs(match_item.?) and slot_item.capacityRemaining() > 0) return index;
                    },
                }
            }

            //switch(search_type) {
            //     .find_empty_slot => |find| {
            //        while (iterator.next()) |index| {
            //            const item_id =
            //            if (item_id == null) {
            //                return index;
            //            }
            //        }
            //     },
            //        .find_slot_same_type => |find| {

            //        while (iterator.next()) |index| {
            //            const item = ecs.get(Component.ItemComponent, item_id.?);
            //            if (item.isSameTypeAs(find.item_to_match)) return index;
            //        }
            //        },
            //}

            //var matching_item = ecs.get(Component.ItemComponent, switch(search_type) {.find});
            return null;
        }

        //pub fn findFirstSlotSameItemType(self: *const @This(), ecs: *ECS, item: ItemComponent) ?Index {
        //    var iterator = self.iterate_items(ecs);
        //    while (iterator.next()) |inventory_item| {
        //        if (item.isSameTypeAs(inventory_item)) return iterator.getIndexOfLastItem();
        //    }
        //    return null;
        //}

        //pub fn findSlotWithSameItemType(self: *const @This(), ecs: *ECS, item_type: []const u8) ?Index {
        //    _ = self; // autofix
        //    _ = ecs; // autofix
        //    _ = item_type; // autofix
        //}

        /// transfers item to first available index in inventory
        pub fn pickupItem(self: *@This(), ecs: *const ECS, item_id: usize) !void {
            const stacking_index = self.findSlot(ecs, .{ .find_slot_for_stacking = .{ .item_id_to_match = item_id } });
            if (stacking_index) |index| {
                self.item_ids[index.x][index.y] = item_id;
            } else {
                const empty_index = self.findSlot(ecs, .{ .find_slot_for_stacking = .{ .item_id_to_match = item_id } });
                if (empty_index) |index| {
                    self.item_ids[index.x][index.y] = item_id;
                } else {
                    return error.OutOfSpace;
                }
            }
        }

        pub fn addItemsToSlot(self: *@This(), ecs: *const ECS, input_item_id: usize, destination_slot: Index) usize {
            _ = self; // autofix
            _ = ecs; // autofix
            _ = input_item_id; // autofix
            _ = destination_slot; // autofix

        }

        pub inline fn numSlots(self: @This()) usize {
            _ = self; // autofix
            return width * height;
        }

        pub fn numFilledSlots(self: *const @This()) usize {
            return self.numSlots() - self.numEmptySlots();
        }

        pub fn numEmptySlots(self: *const @This()) usize {
            var iterator = self.iterate();
            var num_empty_slots: usize = 0;
            while (iterator.next()) |index| {
                if (self.getIndex(index) == null) {
                    num_empty_slots += 1;
                }
            }
            return num_empty_slots;
        }

        pub fn iterate(self: *const @This()) Iterator {
            return Iterator{ .inventory_ptr = self };
        }

        pub fn iterate_items(self: *const @This(), ecs_ptr: *const ECS) ItemIterator {
            return ItemIterator{ .iterator = self.iterate(), .ecs_ptr = ecs_ptr };
        }

        pub const InventoryRenderOptions = struct {
            pub const Corner = enum { top_left, top_right, bottom_left, bottom_right, center_point };
            position: ray.Vector2,
            which_corner: Corner = .center_point,
        };

        fn calculateRenderedWidth(self: *const @This(), window_manager: *const anime.WindowManager) f32 {
            return width * self.default_slot_render_size * window_manager.ui_zoom;
        }

        fn calculateRenderedHeight(self: *const @This(), window_manager: *const anime.WindowManager) f32 {
            return height * self.default_slot_render_size * window_manager.ui_zoom;
        }

        pub fn render(self: *@This(), window_manager: *const anime.WindowManager, entity_component_system: *const ECS, render_opt: InventoryRenderOptions) void {
            const render_width = self.calculateRenderedWidth(window_manager);
            const render_height = self.calculateRenderedHeight(window_manager);
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
                if (self.getIndex(index)) |item_id| {
                    const item = entity_component_system.get(Component.Item, item_id);
                    item.renderInUi(window_manager, anime.addVector2(anime.scaleVector(index.vector2(), self.default_slot_render_size), render_position));
                }
            }
            self.wants_to_close = close_inventory == 1;
        }
    };
}

pub const InventoryComponent = Inventory(4, 4, "Inventory");

pub fn updateInventorySystem(
    self: *ECS,
    a: std.mem.Allocator,
    window_manager: *const anime.WindowManager,
    opt: options.Update,
) !void {
    _ = opt;
    const systems = [_]type{ Component.Inventory, Component.Hitbox };
    const set = self.getSystemDomain(a, &systems);

    for (set) |member| {
        var inventory = self.get(Component.Inventory, member);

        if (inventory.wants_to_close) {
            inventory.state = .hidden;
        }

        if (self.hasComponent(Component.IsPlayer, member)) {
            if (window_manager.keybindings.isPressed("inventory")) {
                inventory.state = .visible_focused;
            }
        }

        const colliders = try coll.findCollidingEntities(self, a, member);
        for (colliders) |entity| {
            if (self.hasComponent(Component.Item, entity)) {
                inventory.pickupItem(self, entity) catch {
                    continue;
                };
                try self.deleteComponent(entity, Component.Physics);
            }
        }
    }
}

pub fn renderItems(
    self: *ECS,
    a: std.mem.Allocator,
    window_manager: *anime.WindowManager,
) void {
    const systems = [_]type{ Component.Item, Component.Physics };
    const set = self.getSystemDomain(a, &systems);

    for (set) |member| {
        const item = self.get(Component.Item, member);
        const physics = self.get(Component.Physics, member);

        item.renderInWorld(window_manager, physics.pos);
    }
}

pub fn renderPlayerInventory(
    self: *ECS,
    a: std.mem.Allocator,
    window_manager: *anime.WindowManager,
) void {
    const systems = [_]type{ Component.IsPlayer, Component.Inventory };
    const set = self.getSystemDomain(a, &systems);

    for (set) |member| {
        const inventory = self.get(Component.Inventory, member);

        if (inventory.state != .hidden) {
            inventory.render(window_manager, self, .{ .position = .{ .x = anime.screenWidth() / 2, .y = anime.screenHeight() / 2 } });
        }
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

///for testing
//fn expectEql(a: anytype, b: anytype) !void {
//  std.testing.expectEqual()
//}
const expectEqual = std.testing.expectEqual;

test "InventoryIterate" {
    const InventoryType = Inventory(4, 4, "test_inv");
    var inventory = InventoryType{};

    var iterator = inventory.iterate();
    try expectEqual(iterator.next().?, InventoryType.Index{ .x = 0, .y = 0 });
    try expectEqual(iterator.next().?, InventoryType.Index{ .x = 1, .y = 0 });
    try expectEqual(iterator.next().?, InventoryType.Index{ .x = 2, .y = 0 });
    try expectEqual(iterator.next().?, InventoryType.Index{ .x = 3, .y = 0 });
    try expectEqual(iterator.next().?, InventoryType.Index{ .x = 0, .y = 1 });
    try expectEqual(iterator.next().?, InventoryType.Index{ .x = 1, .y = 1 });
    try expectEqual(iterator.next().?, InventoryType.Index{ .x = 2, .y = 1 });
    try expectEqual(iterator.next().?, InventoryType.Index{ .x = 3, .y = 1 });
    try expectEqual(iterator.next().?, InventoryType.Index{ .x = 0, .y = 2 });
    try expectEqual(iterator.next().?, InventoryType.Index{ .x = 1, .y = 2 });
    try expectEqual(iterator.next().?, InventoryType.Index{ .x = 2, .y = 2 });
    try expectEqual(iterator.next().?, InventoryType.Index{ .x = 3, .y = 2 });
    try expectEqual(iterator.next().?, InventoryType.Index{ .x = 0, .y = 3 });
    try expectEqual(iterator.next().?, InventoryType.Index{ .x = 1, .y = 3 });
    try expectEqual(iterator.next().?, InventoryType.Index{ .x = 2, .y = 3 });
    try expectEqual(iterator.next().?, InventoryType.Index{ .x = 3, .y = 3 });

    try expectEqual(iterator.next(), null);
}

test "InventoryFirstEmpty" {
    const InventoryType = Inventory(4, 4, "test_inv");
    var inventory = InventoryType{};

    const first_slot = inventory.findFirstEmptySlot();
    try expectEqual(first_slot.?, InventoryType.Index{ .x = 0, .y = 0 });
}

//test "InventoryPickupItem" {
//    //return std.testing.s
//    const InventoryType = Inventory(4, 4, "test_inv");
//    var inventory = InventoryType{};
//
//    const item_id: usize = 1;
//    try inventory.pickupItem(item_id);
//    try std.testing.expect(inventory.numFilledSlots() == 1);
//    try std.testing.expect(inventory.numEmptySlots() == 15);
//    try expectEqual(inventory.getIndex(InventoryType.Index{}), item_id);
//}
