const std = @import("std");
const map = @import("map.zig");
const config = @import("config.zig");
const texture = @import("textures.zig");
const options = @import("options.zig");
const SparseSet = @import("sparse_set.zig").SparseSet;
pub const Component = @import("components.zig");
const ray = @cImport({
    @cInclude("raylib.h");
});

pub fn randomFloat() f32 {
    const state = struct {
        var rng = std.rand.DefaultPrng.init(0);
    };

    const precision: u32 = 1000;
    const rng_value: f32 = @floatFromInt(state.rng.next() % precision);
    return rng_value / precision;
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

inline fn sliceComponentNames() []const std.builtin.Type.Declaration {
    return @typeInfo(Component).Struct.decls;
}

pub fn EcsComponent() type {
    const len = @typeInfo(Component).Struct.decls.len;
    var fields: [len]std.builtin.Type.StructField = undefined;

    for (sliceComponentNames(), 0..) |val, i| {
        const component_type = @field(Component, val.name);
        const default = SparseSet(component_type){};
        fields[i] = .{
            .name = val.name,
            .type = SparseSet(component_type),
            .default_value = @as(*const SparseSet(component_type), &default),
            .is_comptime = false,
            .alignment = 8,
        };
    }

    return @Type(.{ .Struct = .{ .layout = .Auto, .is_tuple = false, .fields = &fields, .decls = &.{} } });
}

pub const ECS = struct {
    availible_ids: std.ArrayListUnmanaged(usize),
    components: EcsComponent(),
    capacity: usize,
    bitflags: SparseSet(std.bit_set.StaticBitSet(sliceComponentNames().len)),
    idBuffer: std.ArrayListUnmanaged(usize), //used by system domain calculations

    //0s remainding capacities to avoid errors when parsing from json
    pub fn prepForStringify(self: *@This(), a: std.mem.Allocator) void {
        _ = a;
        inline for (sliceComponentNames()) |decl| {
            var sys = &@field(self.components, decl.name);
            sys.dense.capacity = 0;
            sys.dense_ids.capacity = 0;
        }
        self.availible_ids.capacity = 0;
        self.bitflags.dense.capacity = 0;
        self.idBuffer.capacity = 0;
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

        var buffer = try std.ArrayListUnmanaged(usize).initCapacity(a, capacity);

        return @This(){
            .availible_ids = ids,
            .components = res,
            .capacity = capacity,
            .bitflags = try SparseSet(std.bit_set.StaticBitSet(sliceComponentNames().len)).init(a, capacity),
            .idBuffer = buffer,
        };
    }

    pub fn newEntity(self: *@This(), a: std.mem.Allocator) ?usize {
        const id = self.availible_ids.popOrNull();
        if (id) |real_id| {
            std.debug.print("created new entity {}\n", .{real_id});
            self.bitflags.insert(a, real_id, std.bit_set.StaticBitSet(sliceComponentNames().len).initEmpty()) catch return null;
        }
        return id;
    }

    pub fn deleteEntity(self: *@This(), a: std.mem.Allocator, id: usize) !void {
        try self.availible_ids.append(a, id);
        inline for (sliceComponentNames()) |decl| {
            try @field(self.components, decl.name).delete(id);
        }
        try self.bitflags.delete(id);
    }

    pub fn addComponent(self: *@This(), a: std.mem.Allocator, id: usize, component: anytype) !void {
        inline for (sliceComponentNames(), 0..) |decl, i| {
            const decl_type = @field(Component, decl.name);

            if (decl_type == @TypeOf(component)) {
                try @field(self.components, decl.name).insert(a, id, component);
                self.bitflags.get(id).?.set(i);
                //std.debug.print("added {s} to {}\n", .{ decl.name, id });
                return;
            }
        }
        return error.invalid_component;
    }

    pub fn deinit(self: *@This(), a: std.mem.Allocator) void {
        inline for (sliceComponentNames()) |decl| {
            @field(self.components, decl.name).deinit(a);
        }
        self.availible_ids.deinit(a);
        self.bitflags.deinit(a);
        self.idBuffer.deinit(a);
    }

    ///Get component, asserts component exists
    pub inline fn get(self: *const ECS, comptime component_T: type, id: usize) *component_T {
        return self.getMaybe(component_T, id).?;
    }

    ///Gets component if it exists;
    pub inline fn getMaybe(self: *const ECS, comptime component_T: type, id: usize) ?*component_T {
        const name = component_T.name;
        return @field(self.components, name).get(id);
    }

    //==================SYSTEMS===============
    pub fn getSystemDomain(self: *ECS, a: std.mem.Allocator, comptime components: []const type) []usize {
        comptime var bit_mask = std.bit_set.StaticBitSet(sliceComponentNames().len).initEmpty();
        comptime for (components) |comp| {
            for (sliceComponentNames(), 0..) |decl, i| {
                if (std.mem.eql(u8, decl.name, comp.name)) {
                    bit_mask.set(i);
                }
            }
        };

        self.idBuffer.clearRetainingCapacity();

        //std.debug.print("bit mask {b}\n", .{bit_mask.mask});
        for (self.bitflags.dense.items, 0..) |component_mask, i| {
            if (bit_mask.mask & component_mask.mask == bit_mask.mask) {
                const id = (self.bitflags.dense_ids.items[i]);
                //std.debug.print("found {s} for {}\n", .{ sliceComponentNames()[i].name, id });

                //check if capacity remains
                self.idBuffer.append(a, id) catch return self.idBuffer.items;
            }
        }

        return self.idBuffer.items;

        //std.debug.print("domain is {any}\n", .{result.items});

        //comptime architype_bit_mask =
        //var arena = std.heap.ArenaAllocator.init(a);
        //defer arena.deinit();
        //const aa = arena.allocator();

        //if (components.len <= 0) {
        //    return std.ArrayList(usize).init(a);
        //}

        ////std.debug.print("\ngetting system domain for {*}\n\n", .{components});
        ////std.debug.print("components.len: {}\n", .{components.len});

        //var found = std.AutoHashMap(usize, u32).init(aa);
        //defer found.deinit();

        //inline for (0..components.len) |i| {
        //    const component_domain = @field(self.components, components[i].name).dense_ids.items;
        //    //std.debug.print("adding {any}\n", .{components[i]});
        //    for (component_domain) |id| {
        //        if (found.get(id)) |count| {
        //            //std.debug.print("found {}\n", .{id});
        //            found.put(id, count + 1) catch return std.ArrayList(usize).init(a);
        //        } else {
        //            //std.debug.print("added {}\n", .{id});
        //            found.put(id, 1) catch return std.ArrayList(usize).init(a);
        //        }
        //    }
        //}

        //var result = std.ArrayList(usize).init(a);

        //var iterator = found.iterator();
        //while (iterator.next()) |entry| {
        //    if (entry.value_ptr.* >= components.len) {
        //        result.append(entry.key_ptr.*) catch return std.ArrayList(usize).init(a);
        //    }
        //}

        //return result;
    }

    //===============RENDERING================
    pub fn render(self: *ECS, a: std.mem.Allocator, texture_state: texture.TextureState, opt: options.Render) void {
        //const set = intersection(a, self.components.render.dense_ids.items, self.components.physics.dense_ids.items, self.capacity);
        //const systems = [_][]const u8{ "physics", "sprite" };
        const systems = [_]type{ Component.physics, Component.sprite };
        const set = self.getSystemDomain(a, &systems);

        for (set) |member| {
            const sprite = self.components.sprite.get(member).?;
            const physics = self.components.physics.get(member).?;

            const my_texture = texture_state.getI(sprite.texture_id);
            const screen_position = ray.Vector2{ .x = physics.pos.x * opt.grid_spacing, .y = physics.pos.y * opt.grid_spacing };
            ray.DrawTextureEx(my_texture, screen_position, 0, opt.scale, ray.WHITE);
        }
    }
};

//pub fn intersection(a: std.mem.Allocator, arr1: []usize, arr2: []usize) []usize {
//    _ = arr2;
//    var found = std.AutoHashMap(usize, bool).init(a);
//    for(arr1) |element| {
//        found.put(element, true);
//    }
//}

test "ECS" {
    var ecs = try ECS.init(std.testing.allocator, 101);
    defer ecs.deinit(std.testing.allocator);

    const player_id = ecs.newEntity(std.testing.allocator).?;
    try ecs.addComponent(std.testing.allocator, player_id, Component.physics{ .pos = .{ .x = 5, .y = 5 } });
    try ecs.addComponent(std.testing.allocator, player_id, Component.is_player{});

    for (0..10) |_| {
        const id = ecs.newEntity(std.testing.allocator).?;
        try ecs.addComponent(std.testing.allocator, id, Component.physics{ .pos = .{ .x = 5, .y = 5 } });
        try ecs.addComponent(std.testing.allocator, id, Component.collider{});
        //std.debug.print("New Entity: {} \n", .{id});
    }

    for (0..91) |id| {
        try ecs.deleteEntity(std.testing.allocator, id);
    }

    {
        const systems = [_]type{Component.physics};
        const set = ecs.getSystemDomain(std.testing.allocator, &systems);
        try std.testing.expect(set.len == 10);
    }

    {
        const systems = [_]type{};
        const set = ecs.getSystemDomain(std.testing.allocator, &systems);
        try std.testing.expect(set.len == 10);
    }

    {
        const systems = [_]type{ Component.physics, Component.is_player };
        const set = ecs.getSystemDomain(std.testing.allocator, &systems);
        try std.testing.expect(set.len == 1);
    }

    try std.testing.expect(ecs.components.is_player.dense.items.len == 1);
    try std.testing.expect(ecs.components.is_player.dense_ids.items.len == 1);
}
