const std = @import("std");
const map = @import("map.zig");
const key = @import("keybindings.zig");
const texture = @import("textures.zig");
const options = @import("options.zig");
const SparseSet = @import("sparse_set.zig").SparseSet;
const Grid = @import("grid.zig").Grid;
pub const Component = @import("components.zig");
const ziglua = @import("ziglua");
const Lua = ziglua.Lua;
const ray = @cImport({
    @cInclude("raylib.h");
});
const api = @import("api.zig");

///range 0.0 to 1.0
pub fn randomFloat() f32 {
    const state = struct {
        var rng = std.rand.DefaultPrng.init(0);
    };

    const precision: u32 = 1000;
    const rng_value: f32 = @floatFromInt(state.rng.next() % precision);
    return rng_value / precision;
}

pub fn tof32(input: anytype) f32 {
    return @floatFromInt(input);
}

pub fn randomVector2(max_x: usize, max_y: usize) ray.Vector2 {
    const state = struct {
        var rng = std.rand.DefaultPrng.init(0);
    };

    const x = state.rng.next() % max_x;
    const y = state.rng.next() % max_y;

    return .{
        .x = @floatFromInt(x),
        .y = @floatFromInt(y),
    };
}

test "randomVector" {
    for (0..100) |_| {
        _ = randomVector2(100, 100);
    }
}

pub fn sliceComponentNames() []const std.builtin.Type.Declaration {
    return @typeInfo(Component).Struct.decls;
}

pub fn intFromComponent(comptime ComponentType: type) usize {
    inline for (comptime sliceComponentNames(), 0..) |val, i| {
        if (@field(Component, val.name) == ComponentType) {
            return i;
        }
    }
    unreachable;
}

pub fn componentFromInt(component_int: usize) []const u8 {
    comptime sliceComponentNames()[component_int];
}

pub fn EcsComponent() type {
    const len = @typeInfo(Component).Struct.decls.len;
    var fields: [len]std.builtin.Type.StructField = undefined;

    for (comptime sliceComponentNames(), 0..) |val, i| {
        const ComponentType = @field(Component, val.name);
        const default = SparseSet(ComponentType){};
        fields[i] = .{
            .name = @typeName(ComponentType),
            .type = SparseSet(ComponentType),
            .default_value = @as(*const SparseSet(ComponentType), &default),
            .is_comptime = false,
            .alignment = 8,
        };
    }

    return @Type(.{ .Struct = .{ .layout = .auto, .is_tuple = false, .fields = &fields, .decls = &.{} } });
}

pub const ECS = struct {
    availible_ids: std.ArrayListUnmanaged(usize),
    components: EcsComponent(),
    capacity: usize,
    bitflags: SparseSet(std.bit_set.StaticBitSet(sliceComponentNames().len)),
    domain_id_buffer: std.ArrayListUnmanaged(usize), //used by system domain calculations
    domain_id_buffer_in_use: bool = false,
    collision_id_buffer: std.ArrayListUnmanaged(usize), //used by collision calculations
    collision_id_buffer_in_use: bool = false,
    position_cache: Grid(std.ArrayListUnmanaged(usize)),

    //0s remainding capacities to avoid errors when parsing from json
    pub fn prepForStringify(self: *@This(), a: std.mem.Allocator) void {
        _ = a;
        inline for (comptime sliceComponentNames()) |decl| {
            var sys = &@field(self.components, @typeName(@field(Component, decl.name)));
            sys.dense.capacity = 0;
            sys.dense_ids.capacity = 0;
        }
        self.availible_ids.capacity = 0;
        self.bitflags.dense.capacity = 0;
        self.domain_id_buffer.capacity = 0;
        self.collision_id_buffer.capacity = 0;
        self.position_cache = .{ .default_value = .{} };
    }

    pub fn init(a: std.mem.Allocator, capacity: usize) !@This() {
        var res = EcsComponent(){};

        inline for (comptime std.meta.fields(EcsComponent())) |f| {
            @field(res, f.name) = try f.type.init(a, capacity);
        }

        var ids = std.ArrayListUnmanaged(usize){};
        for (0..capacity) |id| {
            try ids.append(a, id);
        }

        const domain_id_buffer = try std.ArrayListUnmanaged(usize).initCapacity(a, capacity);
        const collision_id_buffer = try std.ArrayListUnmanaged(usize).initCapacity(a, capacity);

        return @This(){
            .availible_ids = ids,
            .components = res,
            .capacity = capacity,
            .bitflags = try SparseSet(std.bit_set.StaticBitSet(comptime sliceComponentNames().len)).init(a, capacity),
            .domain_id_buffer = domain_id_buffer,
            .collision_id_buffer = collision_id_buffer,
            .position_cache = try Grid(std.ArrayListUnmanaged(usize)).init(a, 32, 32, .{}),
        };
    }

    pub fn newEntity(self: *@This(), a: std.mem.Allocator) ?usize {
        const id = self.availible_ids.popOrNull();
        if (id) |real_id| {
            //std.debug.print("created new entity {}\n", .{real_id});
            self.bitflags.insert(a, real_id, std.bit_set.StaticBitSet(comptime sliceComponentNames().len).initEmpty()) catch return null;
        }
        return id;
    }

    //    pub fn newEntityPtr(self: *@This(), a: *std.mem.Allocator) ?usize {
    //        return self.newEntity(a.*);
    //    }

    pub fn deleteEntity(self: *@This(), a: std.mem.Allocator, id: usize) !void {
        try self.availible_ids.append(a, id);
        inline for (comptime sliceComponentNames()) |decl| {
            try @field(self.components, @typeName(@field(Component, decl.name))).delete(id);
        }
        try self.bitflags.delete(id);
    }

    pub fn setComponent(self: *@This(), a: std.mem.Allocator, id: usize, component: anytype) !void {
        try @field(self.components, @typeName(@TypeOf(component))).set(a, id, component);
        const bitflag = intFromComponent(@TypeOf(component));
        self.bitflags.get(id).?.set(bitflag);
    }

    pub fn deleteComponent(self: *@This(), id: usize, comptime ComponentType: type) !void {
        try @field(self.components, @typeName(ComponentType)).delete(id);
        const bitflag = intFromComponent(ComponentType);
        self.bitflags.get(id).?.unset(bitflag);
    }

    //    pub fn addJsonComponent(self: *@This(), a: *const std.mem.Allocator, id: usize, component_name: []const u8, component_value: ?[]const u8) !void {
    //        inline for (comptime sliceComponentNames()) |decl| {
    //            if (std.mem.eql(u8, component_name, decl.name)) {
    //                const Comp = comptime @field(Component, decl.name);
    //                var value: Comp = undefined;
    //                if (component_value == null) {
    //                    value = Comp{};
    //                } else {
    //                    const parsed = try std.json.parseFromSlice(Comp, a.*, component_value.?, .{ .allocate = .alloc_always });
    //                    value = parsed.value;
    //                }
    //                try self.setComponent(a.*, id, value);
    //                return;
    //            }
    //        }
    //    }

    pub fn deinit(self: *@This(), a: std.mem.Allocator) void {
        inline for (comptime std.meta.fields(EcsComponent())) |f| {
            @field(self.components, f.name).deinit(a);
        }
        self.availible_ids.deinit(a);
        self.bitflags.deinit(a);
        self.collision_id_buffer.deinit(a);
        self.domain_id_buffer.deinit(a);
        self.position_cache.deinit(a);
    }

    ///Get component, asserts component exists
    pub fn get(self: *const ECS, comptime component_T: type, id: usize) *component_T {
        const maybe = self.getMaybe(component_T, id);
        if (maybe) |comp| {
            return comp;
        } else {
            const meta = self.getMaybe(Component.Metadata, id) orelse &Component.Metadata{};
            std.debug.print(
                "\nFailed to find component {} on entity {} with archetype {s}\n",
                .{ component_T, id, meta.archetype },
            );

            const components = self.listComponents(std.heap.c_allocator, id) catch unreachable;
            defer components.deinit();
            std.debug.print("All components of {}: {s}\n", .{ id, components.items });
            unreachable;
        }
    }

    pub inline fn hasComponent(self: *const @This(), comptime ComponentType: type, id: usize) bool {
        return self.bitflags.get(id).?.isSet(intFromComponent(ComponentType));
    }

    ///Gets component if it exists;
    pub inline fn getMaybe(self: *const ECS, comptime ComponentType: type, id: usize) ?*ComponentType {
        return @field(self.components, @typeName(ComponentType)).get(id);
    }

    pub fn listComponents(self: *const ECS, a: std.mem.Allocator, id: usize) !std.ArrayList([]const u8) {
        var result = std.ArrayList([]const u8).init(a);
        inline for (comptime sliceComponentNames()) |decl| {
            if (self.getMaybe(@field(Component, decl.name), id)) |_| {
                try result.append(@typeName(@field(Component, decl.name)));
            }
        }
        return result;
    }

    //==================SYSTEMS===============
    ///Beware: This function changes the contents of domain_id_buffer
    pub fn getSystemDomain(self: *ECS, a: std.mem.Allocator, comptime components: []const type) []usize {
        comptime var bit_mask = std.bit_set.StaticBitSet(sliceComponentNames().len).initEmpty();
        comptime for (components) |comp| {
            bit_mask.set(intFromComponent(comp));
        };

        self.domain_id_buffer.clearRetainingCapacity();

        //std.debug.print("bit mask {b}\n", .{bit_mask.mask});
        for (self.bitflags.dense.items, 0..) |component_mask, i| {
            if (bit_mask.mask & component_mask.mask == bit_mask.mask) {
                const id = (self.bitflags.dense_ids.items[i]);

                inline for (components) |comp| {
                    std.debug.assert(self.getMaybe(comp, id) != null);
                }

                //check if capacity remains
                self.domain_id_buffer.append(a, id) catch unreachable;
            }
        }

        return self.domain_id_buffer.items;
    }

    pub fn getNumEntities(self: @This()) usize {
        return self.capacity - self.availible_ids.items.len;
    }
};

//=================LUA WRAPPERS=====================
//pub fn luaNewEntity(l: *Lua) i32 {
//    var ctx = api.getCtx(l) orelse return 0;
//
//    const a = ctx.allocator.*;
//    const id = ctx.lvl.ecs.newEntity(a) orelse return 0;
//    l.pushInteger(@intCast(id));
//
//    ctx.console.logFmt("Created new entity with id {}", .{id}) catch |err| return api.handleZigError(l, err);
//    return 1;
//}
//
//pub fn luaAddComponent(l: *Lua) i32 {
//    var ctx = api.getCtx(l) orelse return 0;
//    const a = ctx.allocator.*;
//    const id = l.toInteger(1) catch |err| return api.handleZigError(l, err);
//
//    const name = l.toString(2) catch |err| return api.handleZigError(l, err);
//    const name_slice = name[0..std.mem.indexOfSentinel(u8, 0, name)];
//
//    const value = l.toString(3) catch null;
//    var value_slice: ?[]const u8 = null;
//    if (value) |val| {
//        value_slice = val[0..std.mem.indexOfSentinel(u8, 0, val)];
//    }
//
//    ctx.lvl.ecs.addJsonComponent(a, @intCast(id), name_slice, value_slice) catch |err| return api.handleZigError(l, err);
//    ctx.console.logFmt("Added {s} to {}", .{ name_slice, id }) catch |err| return api.handleZigError(l, err);
//    l.pushBoolean(true);
//    return 1;
//}
//
//test "ECS" {
//    var ecs = try ECS.init(std.testing.allocator, 101);
//    defer ecs.deinit(std.testing.allocator);
//
//    const player_id = ecs.newEntity(std.testing.allocator).?;
//    try ecs.setComponent(std.testing.allocator, player_id, Component.physics{ .pos = .{ .x = 5, .y = 5 } });
//    try ecs.setComponent(std.testing.allocator, player_id, Component.is_player{});
//
//    for (0..10) |_| {
//        const id = ecs.newEntity(std.testing.allocator).?;
//        try ecs.setComponent(std.testing.allocator, id, Component.physics{ .pos = .{ .x = 5, .y = 5 } });
//        try ecs.setComponent(std.testing.allocator, id, Component.hitbox{});
//        //std.debug.print("New Entity: {} \n", .{id});
//    }
//
//    for (0..91) |id| {
//        try ecs.deleteEntity(std.testing.allocator, id);
//    }
//
//    {
//        const systems = [_]type{Component.physics};
//        const set = ecs.getSystemDomain(std.testing.allocator, &systems);
//        try std.testing.expect(set.len == 10);
//    }
//
//    {
//        const systems = [_]type{};
//        const set = ecs.getSystemDomain(std.testing.allocator, &systems);
//        try std.testing.expect(set.len == 10);
//    }
//
//    {
//        const systems = [_]type{ Component.physics, Component.is_player };
//        const set = ecs.getSystemDomain(std.testing.allocator, &systems);
//        try std.testing.expect(set.len == 1);
//    }
//
//    try std.testing.expect(ecs.components.is_player.dense.items.len == 1);
//    try std.testing.expect(ecs.components.is_player.dense_ids.items.len == 1);
//}
//
//test "json ecs component" {
//    var ecs = try ECS.init(std.testing.allocator, 101);
//    defer ecs.deinit(std.testing.allocator);
//
//    const player_id = ecs.newEntity(std.testing.allocator).?;
//    try ecs.addJsonComponent(&std.testing.allocator, player_id, "physics", null);
//}

test "system domain" {
    var ecs = try ECS.init(std.testing.allocator, 101);
    defer ecs.deinit(std.testing.allocator);
    const a = std.testing.allocator;

    var list: [50]usize = undefined;
    for (0..50) |i| {
        const slime_id = ecs.newEntity(a).?;
        list[i] = slime_id;
        try ecs.setComponent(a, slime_id, Component.Physics{ .pos = randomVector2(50, 50) });
        try ecs.setComponent(a, slime_id, Component.Sprite{ .animation_player = .{ .animation_name = "slime" } });
        try ecs.setComponent(a, slime_id, Component.Wanderer{});
        try ecs.setComponent(a, slime_id, Component.Health{});
    }

    for (0..24) |i| {
        try ecs.deleteEntity(a, list[i * 2]);
    }

    for (0..12) |i| {
        const slime_id = ecs.newEntity(a).?;
        list[i] = slime_id;
        try ecs.setComponent(a, slime_id, Component.Sprite{ .animation_player = .{ .animation_name = "slime" } });
        try ecs.setComponent(a, slime_id, Component.Wanderer{});
        try ecs.setComponent(a, slime_id, Component.Health{});
        try ecs.setComponent(a, slime_id, Component.Damage{});
    }

    list = undefined;
    for (0..50) |i| {
        const slime_id = ecs.newEntity(a).?;
        list[i] = slime_id;
        try ecs.setComponent(a, slime_id, Component.Physics{ .pos = randomVector2(50, 50) });
        try ecs.setComponent(a, slime_id, Component.Sprite{ .animation_player = .{ .animation_name = "slime" } });
        try ecs.setComponent(a, slime_id, Component.Wanderer{});
        try ecs.setComponent(a, slime_id, Component.Health{});
        try ecs.setComponent(a, slime_id, Component.Hitbox{});
        try ecs.setComponent(a, slime_id, Component.Damage{});
    }

    const domain = ecs.getSystemDomain(a, &[_]type{ Component.Physics, Component.Damage });
    try std.testing.expect(domain.len == list.len);

    for (domain) |id| {
        var found = false;
        for (list) |list_id| {
            if (id == list_id) {
                found = true;
                break;
            }
        }
        if (!found) {
            std.debug.print("list: {any}\n domain: {any}\n", .{ list, domain });
            std.debug.print("Failed to find id {} in list {any}\n", .{ id, list });
            unreachable;
        }
    }
}

//list:   { 50, 49, 48, 47, 46, 45, 44, 43, 42, 41, 40, 39, 38, 37, 36, 35, 34, 33, 32, 31, 30, 29, 28, 27, 26, 25, 24, 23, 22, 21, 20, 19, 18, 17, 16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1 }
//domain: { 50, 49, 48, 47, 46, 45, 44, 43, 42, 41, 40, 39, 38, 37, 36, 35, 34, 33, 32, 31, 30, 29, 28, 27, 26, 25, 24, 23, 22, 21, 20, 19, 18, 17, 16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1 }
