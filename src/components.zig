//const ray = @cImport({
//    @cInclude("raylib.h");
//});
//const Vector2 = ray.Vector2;

const std = @import("std");
const SparseSet = @import("sparse_set.zig").SparseSet;
const Vector2 = struct { x: f32, y: f32 };

pub const Components = [_]type{
    struct {
        const name = "health";
        hp: f64 = 0,
        max_hp: f64 = 0,
        is_dead: bool = false,
        pub fn takeDamage(self: *@This(), damage: f32) void {
            self.*.hp -= damage;
            if (self.*.hp <= 0) {
                self.*.is_dead = true;
            }
        }
    },

    struct {
        const name = "position";
        pos: Vector2 = Vector2{ .x = 0, .y = 0 },
        vel: Vector2 = Vector2{ .x = 0.1, .y = 0.1 },
        acc: Vector2 = Vector2{ .x = 0, .y = 0 },
        friction: f32 = 0.75,
        pub fn update(self: *@This(), dt: f32) void {
            self.pos.x += self.vel.x * dt;
            self.pos.y += self.vel.y * dt;
            self.vel.x += self.acc.x * dt;
            self.vel.y += self.acc.y * dt;
            self.acc.x *= self.friction;
            self.acc.y *= self.friction;
        }
    },

    struct {
        const name = "collision";
        width: f64 = 0,
        height: f64 = 0,
    },

    struct {
        const name = "hostile_ai";
        speed: f64 = 0,
        target: Vector2 = .{ .x = 0, .y = 0 },
        view_range: f64 = 0,
        max_attack_range: f64 = 0,
        min_attack_range: f64 = 0,
        attack_range: f64 = 0,
        action: enum { attack, move, wander } = .wander,
    },

    struct {
        const name = "passive_ai";
        spawn_point: f64 = 0,
        speed_f: f64 = 0,
    },

    struct {
        const name = "renderer";
        //texture: ray.Texture2D,
        pub fn render(self: @This(), pos: Vector2, scale: f32) void {
            _ = self;
            _ = pos;
            _ = scale;
            //TODO uncomment this
            //        ray.DrawTextureEx(self.texture, pos, 0, scale, ray.WHITE);
        }
    },
};

pub fn Spawner() type {
    const len = Components.len;
    var fields: [len]std.builtin.Type.StructField = undefined;
    const nil = null;

    for (Components, 0..) |val, i| {
        fields[i] = .{
            .name = val.name,
            .type = @Type(std.builtin.Type{ .Optional = .{ .child = val } }),
            .default_value = &@as(@Type(std.builtin.Type{ .Optional = .{ .child = val } }), nil),
            .is_comptime = false,
            .alignment = 8,
        };
    }

    return @Type(.{ .Struct = .{ .layout = .Auto, .is_tuple = false, .fields = &fields, .decls = &.{} } });
}

pub fn Systems(comptime cap: usize) type {
    const len = Components.len;
    var fields: [len]std.builtin.Type.StructField = undefined;

    for (Components, 0..) |val, i| {
        const default = SparseSet(val, cap){};
        fields[i] = .{
            .name = val.name,
            .type = SparseSet(val, cap),
            .default_value = &@as(SparseSet(val, cap), default),
            .is_comptime = false,
            .alignment = 8,
        };
    }

    return @Type(.{ .Struct = .{ .layout = .Auto, .is_tuple = false, .fields = &fields, .decls = &.{} } });
}

fn initializeIDs(comptime cap: usize) [cap]usize {
    var array: [cap]usize = undefined;
    @setEvalBranchQuota(cap * 2);
    for (0..cap) |index| {
        array[index] = index;
    }
    return array;
}

pub const EntityState = struct {
    const cap: usize = 1024;
    len: usize = 0,
    ids: [cap]usize = [_]usize{0} ** cap,

    num_available_ids: usize = cap,
    available_ids: [cap]usize = initializeIDs(cap),

    systems: Systems(cap) = Systems(cap){},

    pub fn init(a: std.mem.Allocator) !@This() {
        var res = Systems(cap){};
        inline for (comptime std.meta.fields(Systems(cap))) |f| {
            @field(res, f.name) = try f.type.init(a);
        }
        return @This(){ .systems = res };
    }

    pub fn deinit(self: @This(), a: std.mem.Allocator) void {
        inline for (comptime std.meta.fields(Systems(cap))) |val| {
            var f = @field(self.systems, val.name);
            f.deinit(a);
        }
    }

    pub fn newEntity(self: *@This()) !usize {
        if (self.len > cap) {
            return error.array_at_capacity;
        }
        const id = self.available_ids[self.num_available_ids - 1];
        self.num_available_ids -= 1;
        return id;
    }

    pub fn deleteEntity(self: *@This(), id: usize) !void {
        if (id < 0 or id > self.capacity) {
            return error.index_out_of_bounds;
        }

        self.available_ids[self.num_available_ids] = id;
        self.num_available_ids += 1;

        try self.position_system.delete(id);
        try self.render_system.delete(id);
    }

    pub fn copyEntity(self: *@This(), entity_id: usize) Spawner() {
        var result = Spawner(){};
        inline for (std.meta.fields(Spawner())) |val| {
            if (@field(self.systems, val.name).get(entity_id)) |component| {
                @field(result, val.name) = component.val;
            }
        }
        return result;
    }

    pub fn spawnEntity(self: *@This(), a: std.mem.Allocator, spawned: Spawner()) !void {
        const id = try self.newEntity();

        inline for (std.meta.fields(Spawner())) |val| {
            var f = @field(spawned, val.name);
            if (f) |x| {
                try @field(self.systems, val.name).insert(a, id, x);
            }
        }
    }

    pub fn update(self: *@This(), dt: f32) !void {
        for (self.systems.position.slice()) |*item| {
            item.val.update(dt);
        }
    }

    pub fn render(self: *const @This(), scale: f32) void {
        for (self.systems.render.slice()) |item| {
            const position = self.systems.position.get(item.id).?.val.pos;
            item.val.render(position, scale);
        }
    }

    pub fn transfer(self: *const @This(), a: std.mem.Allocator, destination: *@This(), entity_id: usize) !void {
        const old = self.copyEntity(entity_id);
        try destination.spawnEntity(a, old);
        try self.deleteEntity(entity_id);
    }
};

test "spawner" {
    //std.debug.print("{}\n", .{Spawner(){}});
    //std.debug.print("{}\n", .{EntityState{}});
    var a = try EntityState.init(std.testing.allocator);
    defer a.deinit(std.testing.allocator);
    try a.spawnEntity(std.testing.allocator, .{});
    try a.spawnEntity(std.testing.allocator, .{});
    try a.spawnEntity(std.testing.allocator, .{});
    try a.spawnEntity(std.testing.allocator, .{});
    std.debug.print("\nEntity: {}\n", .{a.copyEntity(1)});
    //std.debug.print("{}\n", .{a.systems.Health});
}
