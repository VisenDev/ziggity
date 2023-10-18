const std = @import("std");
const map = @import("map.zig");
const config = @import("config.zig");
const texture = @import("textures.zig");
const options = @import("options.zig");
const SparseSet = @import("sparse_set.zig").SparseSet;
const intersection = @import("sparse_set.zig").intersection;
const ray = @cImport({
    @cInclude("raylib.h");
});

const vec_default: ray.Vector2 = .{ .x = 0, .y = 0 };

pub const Components = struct {
    pub const physics = struct {
        pub const name = "physics";
        pos: ray.Vector2 = vec_default,
        vel: ray.Vector2 = vec_default,
        acc: ray.Vector2 = vec_default,
        friction: f32 = 0.1,
    };
    pub const health = struct {
        pub const name = "health";
        hp: f32,
        max_hp: f32,
        is_dead: bool,
    };
    pub const sprite = struct {
        pub const name = "sprite";
        texture_id: usize,
        texture_name: []const u8,
    };
    pub const tracker = struct {
        pub const name = "tracker";
        tracked: ?usize,
    };
    pub const movement_particles = struct {
        pub const name = "movement_particles";
        color: ray.Color,
        quantity: u32,
    };
    pub const wanderer = struct {
        pub const name = "wanderer";
        destination: ray.Vector2,
        cooldown: ray.Vector2,
    };
    pub const patroller = struct {
        pub const name = "patroller";
        points: []ray.Vector2,
    };
    pub const mind = struct {
        pub const name = "mind";
        current_activity: []u8,
    };
    pub const eyesight = struct {
        pub const name = "eyesight";
        view_range: f32,
    };
    pub const loot = struct {
        pub const name = "loot";
        item_ids: []usize,
    };
    pub const collider = struct {
        pub const name = "collider";
        hitbox: ray.Rectangle = .{ .x = -1, .y = -1, .width = 2, .height = 2 },
    };
    pub const damage = struct {
        pub const name = "damage";
        type: []u8,
        amount: f32,
        cooldown: f32,
        default_cooldown: f32,
    };
    pub const nametag = struct {
        pub const name = "nametag";
        value: []u8,
    };
    pub const explode_on_death = struct {
        pub const name = "";
        filler: u8 = 0, //this field is here because zig does not like when the struct is empty
    };
    pub const is_player = struct {
        pub const name = "is_player";
        filler: u8 = 0, //this field is here because zig does not like when the struct is empty
    };
};

inline fn sliceComponentNames() []const std.builtin.Type.Declaration {
    return @typeInfo(Components).Struct.decls;
}

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
    sprite: *const Components.sprite,
    nametag: *const Components.nametag,
) void {
    _ = nametag;
    _ = sprite;
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

pub fn EcsComponents() type {
    const len = @typeInfo(Components).Struct.decls.len;
    var fields: [len]std.builtin.Type.StructField = undefined;

    for (sliceComponentNames(), 0..) |val, i| {
        const component_type = @field(Components, val.name);
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
    components: EcsComponents(),
    capacity: usize,

    //0s remainding capacities to avoid errors when parsing from json
    pub fn prepForStringify(self: *@This(), a: std.mem.Allocator) void {
        _ = a;
        inline for (sliceComponentNames()) |decl| {
            var sys = &@field(self.components, decl.name);
            sys.dense.capacity = 0;
        }
        self.availible_ids.capacity = 0;
    }

    pub fn init(a: std.mem.Allocator, capacity: usize) !@This() {
        var res = EcsComponents(){};

        inline for (comptime std.meta.fields(EcsComponents())) |f| {
            @field(res, f.name) = try f.type.init(a, capacity);
        }

        var ids = std.ArrayListUnmanaged(usize){};
        for (0..capacity) |id| {
            try ids.append(a, id);
        }

        return @This(){
            .availible_ids = ids,
            .components = res,
            .capacity = capacity,
        };
    }

    pub fn newEntity(self: *@This(), a: std.mem.Allocator) ?usize {
        _ = a;
        const id = self.availible_ids.popOrNull();
        return id;
    }

    pub fn addComponent(self: *@This(), a: std.mem.Allocator, id: usize, component: anytype) !void {
        inline for (sliceComponentNames()) |decl| {
            const decl_type = @field(Components, decl.name);

            if (decl_type == @TypeOf(component)) {
                try @field(self.components, decl.name).insert(a, id, component);
                return;
            }
        }
        return error.invalid_component;
    }

    pub fn deinit(self: *@This(), a: std.mem.Allocator) void {
        self.availible_ids.deinit(a);
        inline for (sliceComponentNames()) |decl| {
            @field(self.components, decl.name).deinit(a);
        }
    }

    //==================SYSTEMS===============
    pub fn getSystemDomain(self: *const ECS, a: std.mem.Allocator, comptime component_names: []const []const u8) []usize {
        var result: []usize = @field(self.components, component_names[0]).dense_ids.items;
        inline for (1..component_names.len) |i| {
            const component_domain = @field(self.components, component_names[i]).dense_ids.items;
            result = intersection(a, result, component_domain, self.capacity);
        }
        return result;
    }

    pub fn updateMovementSystem(self: *ECS, a: std.mem.Allocator, m: *const map.MapState, opt: options.Update) void {
        _ = opt;
        const systems = [_][]const u8{ "physics", "collider" };
        const set = self.getSystemDomain(a, &systems);
        defer a.free(set);

        for (set) |member| {
            updateMovement(self.components.physics.get(member).?, self.components.collider.get(member).?, &m.collision_grid);
        }
    }

    pub fn updatePlayerSystem(self: *ECS, a: std.mem.Allocator, keys: config.KeyBindings, opt: options.Update) void {
        const systems = [_][]const u8{ "is_player", "physics" };
        const set = self.getSystemDomain(a, &systems);
        defer a.free(set);

        const magnitude: f32 = 100;

        for (set) |member| {
            var direction = ray.Vector2{ .x = 0, .y = 0 };

            if (keys.player_up.pressed()) {
                direction.y -= magnitude;
                std.debug.print("player_up\n", .{});
            }

            if (keys.player_down.pressed()) {
                direction.y += magnitude;
                std.debug.print("player_down\n", .{});
            }

            if (keys.player_left.pressed()) {
                direction.x -= magnitude;
            }

            if (keys.player_right.pressed()) {
                direction.x += magnitude;
            }

            self.components.physics.get(member).?.acc.x = direction.x * opt.dt;
            self.components.physics.get(member).?.acc.y = direction.y * opt.dt;
        }
    }

    //===============RENDERING================
    pub fn render(self: *const ECS, a: std.mem.Allocator, texture_state: texture.TextureState, opt: options.Render) void {
        //const set = intersection(a, self.components.render.dense_ids.items, self.components.physics.dense_ids.items, self.capacity);
        const systems = [_][]const u8{ "physics", "sprite" };
        const set = self.getSystemDomain(a, &systems);
        defer a.free(set);

        for (set) |member| {
            const sprite = self.components.sprite.get(member).?;
            const physics = self.components.physics.get(member).?;

            const my_texture = texture_state.getI(sprite.texture_id);
            const screen_position = ray.Vector2{ .x = physics.pos.x * opt.grid_spacing, .y = physics.pos.y * opt.grid_spacing };
            ray.DrawTextureEx(my_texture, screen_position, 0, opt.scale, ray.WHITE);
        }
    }
};

test "ECS" {
    var ecs = try ECS.init(std.testing.allocator, 100);
    defer ecs.deinit(std.testing.allocator);

    const player_id = ecs.newEntity(std.testing.allocator).?;
    try ecs.addComponent(std.testing.allocator, player_id, Components.physics{ .pos = .{ .x = 5, .y = 5 } });
    try ecs.addComponent(std.testing.allocator, player_id, Components.is_player{});

    try std.testing.expect(ecs.components.is_player.dense.items.len == 1);
    try std.testing.expect(ecs.components.is_player.dense_ids.items.len == 1);
}

//pub const Core = struct {
//    ecs: ECS,
//    entity_cache_map: Grid(std.ArrayListUnmanaged(usize)),
//    collision_map: Grid(bool),
//    texture_map: Grid(usize),
//    texture_ornament_map: Grid(usize),
//};
