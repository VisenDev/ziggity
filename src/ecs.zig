const std = @import("std");
const map = @import("map.zig");
const options = @import("options.zig");
const SparseSet = @import("sparse_set.zig").SparseSet;
const intersection = @import("sparse_set.zig").intersection;
const Grid = @import("grid.zig").Grid;
const ray = @cImport({
    @cInclude("raylib.h");
});

pub const Components = struct {
    pub const physics = struct {
        pos: ray.Vector2,
        vel: ray.Vector2,
        acc: ray.Vector2,
        friction: f32,
    };
    pub const health = struct {
        hp: f32,
        max_hp: f32,
        is_dead: bool,
    };
    pub const render = struct {
        texture_id: usize,
        texture_name: []const u8,
    };
    pub const tracker = struct {
        tracked: ?usize,
    };
    pub const hostility = struct {
        will_attack: []usize,
    };
    pub const movement_particles = struct {
        color: ray.Color,
        quantity: u32,
    };
    pub const wander = struct {
        destination: ray.Vector2,
        cooldown: ray.Vector2,
    };
    pub const patrol = struct {
        points: []ray.Vector2,
    };
    pub const mind = struct {
        current_activity: []u8,
    };
    pub const eyesight = struct {
        view_range: f32,
    };
    pub const loot = struct {
        item_ids: []usize,
    };
    pub const collider = struct {
        hitbox: ray.Rectangle,
    };
    pub const damage = struct {
        type: []u8,
        amount: f32,
        cooldown: f32,
        default_cooldown: f32,
    };
    pub const nametag = struct {
        value: []u8,
    };
    pub const explode_on_death = bool;
    pub const die_on_collision = bool;
    pub const targetable = bool;
    pub const is_player = bool;
};

pub fn checkCollision(
    position: ray.Vector2,
    collider: *const Components.collider,
    collision_grid: *const map.Grid(bool),
) bool {
    _ = collision_grid;
    _ = collider;
    _ = position;
    return false;
}

pub fn updateMovement(
    physics: *Components.physics,
    collider: *Components.collider,
    collision_grid: *const map.Grid(bool),
) void {

    //cache position;
    const old_position = physics.pos;

    physics.pos.x += physics.vel.x;
    physics.pos.y += physics.vel.y;

    physics.vel.x += physics.acc.x;
    physics.vel.y += physics.acc.y;

    physics.vel.x *= physics.friction;
    physics.vel.y *= physics.friction;

    physics.acc.x *= physics.friction;
    physics.acc.y *= physics.friction;

    if (checkCollision(physics.pos, collider, collision_grid)) {
        physics.pos = old_position;
    }
}

pub fn render(
    position: ray.Vector2,
    renderer: *const Components.renderer,
    nametag: *const Components.nametag,
) void {
    _ = nametag;
    _ = renderer;
    _ = position;
}

pub fn updateHostileAI(
    physics: *const Components.physics,
    tracker: *Components.tracker,
    mind: *const Components.mind,
    eyesight: *const Components.patrol,
) void {
    _ = eyesight;
    _ = tracker;
    _ = mind;
    _ = physics;
}

pub fn CreateComponentSparseSets() type {
    const len = @typeInfo(Components).Struct.decls.len;
    var fields: [len]std.builtin.Type.StructField = undefined;

    for (@typeInfo(Components).Struct.decls, 0..) |val, i| {
        const component_type = @field(Components, val.name);
        const default = SparseSet(component_type){};
        fields[i] = .{
            .name = val.name,
            .type = SparseSet(component_type),
            .default_value = &@as(SparseSet(component_type), default),
            .is_comptime = false,
            .alignment = 8,
        };
    }

    return @Type(.{ .Struct = .{ .layout = .Auto, .is_tuple = false, .fields = &fields, .decls = &.{} } });
}

pub const ECS = struct {
    components: CreateComponentSparseSets(),
    capacity: usize,

    //0s remainding capacities to avoid errors when parsing from json
    pub fn prepForStringify(self: *@This()) void {
        inline for (comptime std.meta.fields(CreateComponentSparseSets())) |f| {
            var sys = &@field(self.components, f.name);
            sys.dense.capacity = 0;
        }
    }

    pub fn updateMovementSystem(self: *ECS, a: std.mem.Allocator, m: *const map.MapState, opt: options.Update) void {
        _ = opt;
        const set = intersection(a, self.components.physics.dense_ids.items, self.components.collider.dense_ids.items, self.capacity);
        defer a.free(set);

        for (set) |member| {
            updateMovement(self.components.physics.get(member).?, self.components.collider.get(member).?, &m.collision_grid);
        }
    }

    pub fn init(a: std.mem.Allocator, capacity: usize) !@This() {
        var res = CreateComponentSparseSets(){};
        inline for (comptime std.meta.fields(CreateComponentSparseSets())) |f| {
            @field(res, f.name) = try f.type.init(a, capacity);
        }
        return @This(){ .components = res, .capacity = capacity };
    }

    pub fn deinit(self: @This(), a: std.mem.Allocator) void {
        inline for (comptime std.meta.fields(CreateComponentSparseSets())) |f| {
            @field(self, f.name).deinit(a);
        }
    }
};

test "ECS" {
    var ecs = ECS{};
    ecs.movementSystem();
}

//pub const Core = struct {
//    ecs: ECS,
//    entity_cache_map: Grid(std.ArrayListUnmanaged(usize)),
//    collision_map: Grid(bool),
//    texture_map: Grid(usize),
//    texture_ornament_map: Grid(usize),
//};
