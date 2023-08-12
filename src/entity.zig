const std = @import("std");
const Sparse = @import("sparse_set.zig").SparseSet;
const tex = @import("textures.zig");
const ray = @cImport({
    @cInclude("raylib.h");
});

const Vector2 = ray.Vector2;

fn AvailableInitializer(comptime capacity: usize) [capacity]usize {
    var array: [capacity]usize = undefined;
    for (0..capacity) |index| {
        array[index] = index;
    }
    return array;
}

pub fn EntityState(comptime max_capacity: usize) type {
    return struct {
        capacity: usize = max_capacity,
        ids: std.ArrayList(usize),
        available_ids: std.ArrayList(usize),

        position_system: Sparse(PositionComponent, max_capacity),
        render_system: Sparse(RenderComponent, max_capacity),

        pub fn init(a: std.mem.Allocator) !@This() {
            var available = std.ArrayList(usize).init(a);
            try available.appendSlice(&AvailableInitializer(max_capacity));

            return @This(){
                .ids = std.ArrayList(usize).init(a),
                .available_ids = available,
                .position_system = Sparse(PositionComponent, max_capacity).init(a),
                .render_system = Sparse(RenderComponent, max_capacity).init(a),
            };
        }

        pub fn deinit(self: *@This()) void {
            self.ids.deinit();
            self.available_ids.deinit();

            self.position_system.deinit();
            self.render_system.deinit();
        }

        pub fn newEntity(self: *@This()) !usize {
            if (self.ids.items.len > max_capacity) {
                return error.array_at_capacity;
            }
            const id = self.available_ids.pop();
            return id;
        }

        pub fn deleteEntity(self: *@This(), id: usize) !void {
            if (id < 0 or id > self.capacity) {
                return error.index_out_of_bounds;
            }

            try self.available_ids.append(id);
            try self.position_system.delete(id);
            try self.render_system.delete(id);
        }

        const Spawner = struct {
            position: ?PositionComponent = null,
            renderer: ?RenderComponent = null,
        };

        pub fn spawn(self: *@This(), spawned: Spawner) !void {
            const id = try self.newEntity();
            if (spawned.position) |pos| {
                try self.position_system.insert(id, pos);
            }
            if (spawned.renderer) |renderer| {
                try self.render_system.insert(id, renderer);
            }
        }

        pub fn update(self: *@This(), dt: f32) !void {
            for (self.position_system.slice()) |*item| {
                item.val.update(dt);
            }
        }

        pub fn render(self: *@This(), scale: f32) !void {
            for (self.render_system.slice()) |item| {
                const position = self.position_system.get(item.id).?.val.pos;
                try item.val.render(position, scale);
            }
        }
    };
}

test "state" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var state = try EntityState(1024).init(gpa.allocator());
    _ = try state.newEntity();
    _ = try state.newEntity();
    _ = try state.newEntity();
    const entity = try state.newEntity();
    _ = try state.newEntity();
    _ = try state.newEntity();
    try state.deleteEntity(entity);
    _ = try state.newEntity();
    _ = try state.newEntity();

    const e = try state.newEntity();
    try state.position_system.insert(e, PositionComponent{});

    for (0..10) |_| {
        const id = try state.newEntity();
        try state.position_system.insert(id, PositionComponent{});
    }

    try state.update(1.0);
}

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
    pub fn render(self: @This(), pos: Vector2, scale: f32) !void {
        ray.DrawTextureEx(self.texture, pos, 0, scale, ray.WHITE);
    }
};
