const std = @import("std");
const Sparse = @import("sparse_set.zig").SparseSet;
const tex = @import("textures.zig");
const collide = @import("collisions.zig");
const ray = @cImport({
    @cInclude("raylib.h");
});

const Vector2 = ray.Vector2;
const max_capacity = 248;

fn initializeIDs() [max_capacity]usize {
    var array: [max_capacity]usize = undefined;
    for (0..max_capacity) |index| {
        array[index] = index;
    }
    return array;
}

pub const EntityState = struct {
    capacity: usize = max_capacity,

    len: usize = 0,
    ids: [max_capacity]usize = undefined,

    num_available_ids: usize = max_capacity,
    available_ids: [max_capacity]usize = initializeIDs(),

    position_system: Sparse(PositionComponent, max_capacity),
    render_system: Sparse(RenderComponent, max_capacity),

    pub fn init(a: std.mem.Allocator) !@This() {
        return @This(){
            .position_system = try Sparse(PositionComponent, max_capacity).init(a),
            .render_system = try Sparse(RenderComponent, max_capacity).init(a),
        };
    }

    pub fn deinit(self: *@This(), a: std.mem.Allocator) void {
        self.position_system.deinit(a);
        self.render_system.deinit(a);
    }

    pub fn newEntity(self: *@This()) !usize {
        if (self.len > max_capacity) {
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

    const Spawner = struct {
        position: ?PositionComponent = null,
        renderer: ?RenderComponent = null,
    };

    pub fn spawn(self: *@This(), a: std.mem.Allocator, spawned: Spawner) !void {
        const id = try self.newEntity();
        if (spawned.position) |pos| {
            try self.position_system.insert(a, id, pos);
        }
        if (spawned.renderer) |renderer| {
            try self.render_system.insert(a, id, renderer);
        }
    }

    pub fn update(self: *@This(), dt: f32) !void {
        for (self.position_system.slice()) |*item| {
            item.val.update(dt);
        }
    }

    pub fn render(self: *@This(), scale: f32) void {
        for (self.render_system.slice()) |item| {
            const position = self.position_system.get(item.id).?.val.pos;
            item.val.render(position, scale);
        }
    }
};

const HealthComponent = struct {
    hp: f64 = 0,
    max_hp: f64 = 0,
    is_dead: bool = false,

    pub fn takeDamage(self: *@This(), damage: f32) void {
        self.*.hp -= damage;
        if (self.*.hp <= 0) {
            self.*.is_dead = true;
        }
    }
};

pub const PositionComponent = struct {
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
};

const CollisionComponent = struct {
    width: f64 = 0,
    height: f64 = 0,
};

const HostileAIComponent = struct {
    speed: f64 = 0,
    target: Vector2,
    view_range: f64 = 0,
    max_attack_range: f64 = 0,
    min_attack_range: f64 = 0,
    attack_range: f64 = 0,
    action: enum { attack, move, wander } = @This().action.wander,
};

const PassiveAIComponent = struct {
    spawn_point: f64 = 0,
    speed_f: f64 = 0,
};

//const PlayerControllerComponent = struct {
//    pub fn update() void {}
//};

pub const RenderComponent = struct {
    texture: ray.Texture2D,
    pub fn render(self: @This(), pos: Vector2, scale: f32) void {
        ray.DrawTextureEx(self.texture, pos, 0, scale, ray.WHITE);
    }
};
