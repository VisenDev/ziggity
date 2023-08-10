const std = @import("std");
const Sparse = @import("sparse_set.zig").SparseSet;

const Vector2 = struct {
    x: f64 = 0,
    y: f64 = 0,
};

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

        health_system: Sparse(HealthComponent, max_capacity),
        position_system: Sparse(PositionComponent, max_capacity),
        collision_system: Sparse(CollisionComponent, max_capacity),
        hostile_ai_system: Sparse(HostileAIComponent, max_capacity),
        passive_ai_system: Sparse(PassiveAIComponent, max_capacity),

        render_system: Sparse(RenderComponent, max_capacity),

        pub fn init(a: std.mem.Allocator) !@This() {
            var available = std.ArrayList(usize).init(a);
            try available.appendSlice(&AvailableInitializer(max_capacity));

            return @This(){
                .ids = std.ArrayList(usize).init(a),
                .available_ids = available,
                .health_system = Sparse(HealthComponent, max_capacity).init(a),
                .position_system = Sparse(PositionComponent, max_capacity).init(a),
                .collision_system = Sparse(CollisionComponent, max_capacity).init(a),
                .hostile_ai_system = Sparse(HostileAIComponent, max_capacity).init(a),
                .passive_ai_system = Sparse(PassiveAIComponent, max_capacity).init(a),
                .render_system = Sparse(RenderComponent, max_capacity).init(a),
            };
        }

        pub fn deinit(self: *@This()) void {
            self.ids.deinit();
            self.available_ids.deinit();

            self.health_system.deinit();
            self.position_system.deinit();
            self.collision_system.deinit();
            self.hostile_ai_system.deinit();
            self.passive_ai_system.deinit();
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
            try self.health_system.delete(id);
            try self.position_system.delete(id);
            try self.collision_system.delete(id);
            try self.hostile_ai_system.delete(id);
            try self.passive_ai_system.delete(id);
            try self.render_system.delete(id);
        }

        pub fn update(self: *@This(), dt: f64) !void {
            for (self.position_system.iterate()) |val| {
                val.update(dt);
            }
        }

        pub fn render(self: *@This(), scale: f64) !void {
            for (self.render_system.iterate()) |val| {
                val.render(scale);
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
    try state.health_system.insert(e, HealthComponent{});
    try state.position_system.insert(e, PositionComponent{});

    for (0..10) |_| {
        const id = try state.newEntity();
        try state.health_system.insert(id, HealthComponent{ .hp = 10 });
        try state.position_system.insert(id, PositionComponent{});
    }

    for (state.health_system.iterate()) |val| {
        std.debug.print("{}\n", .{val});
    }
}

const HealthComponent = struct {
    hp: f64 = 0,
    max_hp: f64 = 0,
    is_dead: bool = false,

    pub fn takeDamage(self: *@This(), damage: f64) void {
        self.*.hp -= damage;
        if (self.*.hp <= 0) {
            self.*.is_dead = true;
        }
    }
};

const PositionComponent = struct {
    pos: Vector2,
    vel: Vector2,
    acc: Vector2,
    friction: f64 = 0.75,

    pub fn update(self: *@This(), id: usize, dt: f64) void {
        _ = id;
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

const RenderComponent = struct {
    texture_id: u64 = 0,
    pub fn render(scale: f64) !void {
        _ = scale;
    }
};
