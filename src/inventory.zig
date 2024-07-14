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
const item_actions = @import("item_actions.zig");
const Component = @import("components.zig");
const intersection = @import("sparse_set.zig").intersection;

const ray = @cImport({
    @cInclude("raylib.h");
});

const raygui = @cImport({
    @cInclude("raygui.h");
    @cInclude("style_dark.h");
});

const eql = std.mem.eql;

//pub const ItemActions = struct {
//    pub  fireball =
//}

//pub const ItemAction = enum {fireball, spawn_slime
//
//    pub fn do(self: @This()) void {
//        inline for(ItemAction) |action| {
//            if(
//        }
////        switch(self) {
//
//        //}
//    }
//};

// =========Component types=========
pub const ItemComponent = struct {
    pub const name = "item";

    pub const ItemActionEnum = std.meta.DeclEnum(item_actions);
    type_of_item: [:0]const u8 = "unknown",
    category_of_item: [:0]const u8 = "unknown",
    stack_size: usize = 1,
    max_stack_size: usize = 16,
    animation_player: anime.AnimationPlayer = .{ .animation_name = "potion" },
    action: ?ItemActionEnum = null,

    pub fn renderInUi(self: *const @This(), window_manager: *const anime.WindowManager, screen_position: ray.Vector2, ui_render_size: f32) void {
        //const scale_adjustment = ui_render_size / window_manager.animations.get(self.animation_player.animation_name).?.frames[0].subrect.width;
        self.animation_player.renderOnScreen(window_manager, screen_position, .{ .width_override = ui_render_size, .height_override = ui_render_size });

        var buffer: [256]u8 = [_]u8{0} ** 256;
        _ = std.fmt.bufPrintZ(&buffer, "{}", .{self.stack_size}) catch {};
        ray.DrawTextEx(ray.GetFontDefault(), (&buffer).ptr, screen_position, ui_render_size / 2, 1, ray.RAYWHITE);
    }

    pub fn renderInWorld(self: *const @This(), window_manager: *const anime.WindowManager, tile_coordinates: ray.Vector2) void {
        self.animation_player.renderInWorld(window_manager, tile_coordinates, .{});

        const world_position = window_manager.tileToWorld(tile_coordinates);
        var buffer: [256]u8 = [_]u8{0} ** 256;
        _ = std.fmt.bufPrintZ(&buffer, "{}", .{self.stack_size}) catch {};
        ray.DrawTextEx(ray.GetFontDefault(), (&buffer).ptr, world_position, 10, 1, ray.RAYWHITE);
    }

    pub fn isSameTypeAs(self: *const @This(), other_item: *const @This()) bool {
        return std.mem.eql(u8, self.type_of_item, other_item.type_of_item);
    }

    pub fn capacityRemaining(self: *const @This()) usize {
        return self.max_stack_size - self.stack_size;
    }

    pub fn combineWith(self: *@This(), combined_item: *@This()) void {
        if (combined_item.stack_size <= self.capacityRemaining()) {
            self.stack_size += combined_item.stack_size;
            combined_item.stack_size = 0;
        } else {
            combined_item.stack_size -= self.capacityRemaining();
            self.stack_size = self.max_stack_size;
        }
    }

    pub fn shouldBeDeleted(self: @This()) bool {
        return self.stack_size <= 0;
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

            pub fn initFromVector2(v: raygui.Vector2) @This() {
                return .{
                    .x = @intFromFloat(v.x),
                    .y = @intFromFloat(v.y),
                };
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
        slot_render_size: f32 = 32,
        state: enum { visible_focused, visible, hidden } = .hidden,
        hovered_index: ?Index = null,

        pub fn getIndex(self: *const @This(), index: Index) ItemId {
            return self.item_ids[index.x][index.y];
        }

        pub fn getSelectedItemId(self: *const @This()) ItemId {
            return self.getIndex(self.selected_index);
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
                        if (slot_item_id) |id| {
                            const slot_item = ecs.get(Component.Item, id);
                            if (slot_item.isSameTypeAs(match_item.?)) return index;
                        }
                    },
                    .find_slot_for_stacking => {
                        if (slot_item_id) |id| {
                            const slot_item = ecs.get(Component.Item, id);
                            if (slot_item.isSameTypeAs(match_item.?) and slot_item.capacityRemaining() > 0) return index;
                        }
                    },
                }
            }

            return null;
        }

        /// transfers item to first available index in inventory
        pub fn pickupItem(self: *@This(), a: std.mem.Allocator, ecs: *ECS, item_id: usize) !void {
            const stacking_index = self.findSlot(ecs, .{ .find_slot_for_stacking = .{ .item_id_to_match = item_id } });
            const empty_index = self.findSlot(ecs, .{ .find_empty_slot = {} });
            if (stacking_index) |index| {
                const status = try self.addItemsToSlot(a, ecs, item_id, index);
                if (status == .not_all_items_merged) {
                    try self.pickupItem(a, ecs, item_id);
                }
            } else if (empty_index) |index| {
                self.item_ids[index.x][index.y] = item_id;

                try ecs.deleteComponent(item_id, Component.Physics);
            } else {
                return error.OutOfSpace;
            }
        }

        const AddItemStatus = enum { all_items_merged, not_all_items_merged };
        pub fn addItemsToSlot(self: *@This(), a: std.mem.Allocator, ecs: *ECS, input_item_id: usize, destination_slot: Index) !AddItemStatus {
            const input_item = ecs.get(Component.Item, input_item_id);
            const destination_item = ecs.get(Component.Item, self.getIndex(destination_slot).?);
            destination_item.combineWith(input_item);
            if (input_item.shouldBeDeleted()) {
                try ecs.deleteEntity(a, input_item_id);
                return .all_items_merged;
            } else {
                return .not_all_items_merged;
            }
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
            return width * self.slot_render_size * window_manager.ui_zoom;
        }

        fn calculateRenderedHeight(self: *const @This(), window_manager: *const anime.WindowManager) f32 {
            return height * self.slot_render_size * window_manager.ui_zoom;
        }

        pub fn updateMouseInteractions(self: *@This(), window_manager: *const anime.WindowManager, entity_component_system: *const ECS) !void {
            _ = entity_component_system; // autofix
            if (window_manager.getMouseOwner() == .player_inventory) {
                if (self.hovered_index != null and window_manager.isMousePressed(.left)) {
                    self.selected_index = self.hovered_index.?;
                    std.debug.print("selected_index: {}\n", .{self.selected_index});
                }
            }
        }

        pub fn render(self: *@This(), window_manager: *const anime.WindowManager, entity_component_system: *const ECS, render_opt: InventoryRenderOptions) void {
            const render_width = self.calculateRenderedWidth(window_manager);
            const render_height = self.calculateRenderedHeight(window_manager);
            const render_position: ray.Vector2 = switch (render_opt.which_corner) {
                .center_point => .{ .x = render_opt.position.x - (render_width / 2), .y = render_opt.position.y - (render_height / 2) },
                .top_left => render_opt.position,
                else => @panic("not implemented yet"),
            };

            const render_window_bounds: raygui.Rectangle = .{
                .x = render_position.x,
                .y = render_position.y,
                .width = render_width,
                .height = render_height,
            };

            const null_mouse_pos: raygui.Vector2 = .{ .x = -1, .y = -1 };
            var mouse_pos: raygui.Vector2 = null_mouse_pos;

            _ = raygui.GuiGrid(render_window_bounds, "Player Inventory", self.slot_render_size, @intFromFloat(self.slot_render_size), &mouse_pos);

            if (std.meta.eql(mouse_pos, null_mouse_pos)) {
                self.hovered_index = null;
            } else {
                self.hovered_index = Index.initFromVector2(mouse_pos);
            }

            var iterator = self.iterate();
            while (iterator.next()) |index| {
                const final_position = anime.addVector2(anime.scaleVector(index.vector2(), self.slot_render_size), render_position);

                if (self.selected_index.x == index.x and self.selected_index.y == index.y) {
                    ray.DrawRectangleV(final_position, .{ .x = self.slot_render_size, .y = self.slot_render_size }, ray.GRAY);
                }

                if (self.getIndex(index)) |item_id| {
                    const item = entity_component_system.get(Component.Item, item_id);
                    item.renderInUi(window_manager, final_position, self.slot_render_size * 0.9);
                }
            }
        }
    };
}

pub const InventoryComponent = Inventory(4, 4, "Inventory");

pub fn updateInventorySystem(
    self: *ECS,
    a: std.mem.Allocator,
    window_manager: *anime.WindowManager,
    m: *map.MapState,
    opt: options.Update,
) !void {
    _ = opt;
    const systems = [_]type{ Component.Inventory, Component.Hitbox };
    const set = self.getSystemDomain(a, &systems);

    for (set) |member| {
        var inventory = self.get(Component.Inventory, member);

        try inventory.updateMouseInteractions(window_manager, self);

        if (self.hasComponent(Component.IsPlayer, member)) {
            if (window_manager.keybindings.isPressed("inventory")) {
                if (inventory.state == .hidden) {
                    inventory.state = .visible_focused;
                    try window_manager.takeMouseOwnership(.player_inventory);
                } else {
                    inventory.state = .hidden;
                    try window_manager.relinquishMouseOwnership(.player_inventory);
                }
            }
        }

        const colliders = try coll.findCollidingEntities(self, a, m, member);
        for (colliders) |entity| {
            //std.debug.print("colliding item found: {}\n", .{entity});
            if (self.hasComponent(Component.Item, entity)) {
                inventory.pickupItem(a, self, entity) catch continue;
            }
        }
    }
}

pub fn updateItemSystem(
    self: *ECS,
    a: std.mem.Allocator,
    window_manager: *anime.WindowManager,
    opt: options.Update,
) !void {
    const systems = [_]type{Component.Item};
    const set = self.getSystemDomain(a, &systems);

    for (set) |member| {
        const item = self.get(Component.Item, member);
        if (item.action) |action| {
            //std.meta.tags(Component.Item.ItemActionEnum)
            //try @field(item_actions, @tagName(action)).do(member, self, window_manager, opt);
            inline for (@typeInfo(item_actions).Struct.decls) |decl| {
                if (std.mem.eql(u8, decl.name, @tagName(action))) {
                    try @field(item_actions, decl.name).do(member, self, window_manager, opt);
                }
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

test "FindEmpty" {
    const InventoryType = Inventory(4, 4, "test_inv");
    var inventory = InventoryType{};

    const a = std.testing.allocator;
    var ecs = try ECS.init(a, 101);
    defer ecs.deinit(a);

    const first_slot = inventory.findSlot(&ecs, .{ .find_empty_slot = {} });
    try expectEqual(first_slot.?, InventoryType.Index{ .x = 0, .y = 0 });
}

test "InventoryEmptyPickupItem" {
    const a = std.testing.allocator;

    var ecs = try ECS.init(a, 101);
    defer ecs.deinit(a);

    const item_id_1 = ecs.newEntity(a).?;
    try ecs.setComponent(a, item_id_1, Component.Item{});

    const InventoryType = Inventory(4, 4, "test_inv");
    var inventory = InventoryType{};

    try inventory.pickupItem(a, &ecs, item_id_1);
    try std.testing.expect(inventory.numFilledSlots() == 1);
    try std.testing.expect(inventory.numEmptySlots() == 15);
    try expectEqual(inventory.getIndex(InventoryType.Index{}), item_id_1);
}

test "FindSameType" {
    const InventoryType = Inventory(4, 4, "test_inv");
    var inventory = InventoryType{};

    const a = std.testing.allocator;
    var ecs = try ECS.init(a, 101);
    defer ecs.deinit(a);

    const item_id_1 = ecs.newEntity(a).?;
    try ecs.setComponent(a, item_id_1, Component.Item{});
    try inventory.pickupItem(a, &ecs, item_id_1);

    const found_slot = inventory.findSlot(&ecs, .{ .find_slot_same_type = .{ .item_id_to_match = item_id_1 } });
    try expectEqual(found_slot.?, InventoryType.Index{ .x = 0, .y = 0 });
}

test "StackingPickupItem" {
    const InventoryType = Inventory(4, 4, "test_inv");
    var inventory = InventoryType{};

    const a = std.testing.allocator;
    var ecs = try ECS.init(a, 101);
    defer ecs.deinit(a);

    const item_id_1 = ecs.newEntity(a).?;
    try ecs.setComponent(a, item_id_1, Component.Item{});
    try inventory.pickupItem(a, &ecs, item_id_1);

    const item_id_2 = ecs.newEntity(a).?;
    try ecs.setComponent(a, item_id_2, Component.Item{});
    try inventory.pickupItem(a, &ecs, item_id_2);
}
