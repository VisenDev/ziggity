const std = @import("std");
const Lua = @import("ziglua").Lua;
const anime = @import("animation.zig");
const map = @import("map.zig");
const texture = @import("textures.zig");
const tile = @import("tiles.zig");
const file = @import("file_utils.zig");
const key = @import("keybindings.zig");
const ecs = @import("ecs.zig");
//const event = @import("events.zig");
const ray = @cImport({
    @cInclude("raylib.h");
});

pub const UpdateOptions = struct {
    keys: *const key.KeyBindings,
    dt: f32,
};

pub const Exit = struct {
    x: u32,
    y: u32,
    destination_id: []const u8,
};

pub const Record = struct {
    name: []const u8,
    weight: u32,
};

pub const LevelGenOptions = struct {
    name: []const u8,
    biomes: []const Record = &[_]Record{},
    density: f64 = 0.4,
    width: u32 = 50,
    height: u32 = 50,
};

pub const Level = struct {
    name: []const u8 = "",
    ecs: *ecs.ECS = undefined,
    map: *map.MapState = undefined,
    exits: []const Exit = &[_]Exit{},
    player_id: usize = 0,
};

pub fn generateLevel(a: std.mem.Allocator, lua: *Lua, options: LevelGenOptions) !Level {
    _ = options;

    var tile_state = try tile.TileState.init(a, lua);
    defer tile_state.deinit();

    var entities = try a.create(ecs.ECS);
    entities.* = try ecs.ECS.init(a, 10000);

    const map_string = try lua.autoCall([]const u8, "Generate", .{});

    const world_map = try a.create(map.MapState);
    world_map.* = try map.MapState.generateFromString(a, tile_state, map_string);
    //world_map.* = try map.MapState.generate(a, tile_state, options);

    var exits = try a.alloc(Exit, 1);
    exits[0] = Exit{ .x = 5, .y = 5, .destination_id = "first_level" };

    var copy = a;
    const player_id = try lua.autoCall(?usize, "SpawnPlayer", .{ entities, &copy }) orelse return error.failed_to_create_player;
    try entities.setComponent(a, player_id, ecs.Component.physics{ .pos = .{ .x = 3, .y = 5 } });

    return Level{ .name = "harry truman", .ecs = entities, .map = world_map, .exits = exits, .player_id = player_id };
}
