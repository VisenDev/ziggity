const std = @import("std");
const arch = @import("archetypes.zig");
const Lua = @import("ziglua").Lua;
const anime = @import("animation.zig");
const MapState = @import("map.zig").MapState;
const texture = @import("textures.zig");
const tile = @import("tiles.zig");
const file = @import("file_utils.zig");
const key = @import("keybindings.zig");
const ecs = @import("ecs.zig");
const ray = @cImport({
    @cInclude("raylib.h");
});

//pub const Exit = struct {
//    x: u32,
//    y: u32,
//    destination_id: []const u8,
//};

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
    ecs: *ecs.ECS,
    map: *MapState,
    //exits: []const Exit = &[_]Exit{},
    //player_id: usize = 0,

    pub fn generate(a: std.mem.Allocator, lua: *Lua, options: LevelGenOptions) !Level {
        var tile_state = try tile.TileState.init(a, lua);
        defer tile_state.deinit();

        var entities = try a.create(ecs.ECS);
        entities.* = try ecs.ECS.init(a, 10000);

        const world_map = try a.create(MapState);
        world_map.* = try MapState.generate(a, &tile_state, options);

        const player_id = try arch.createPlayer(entities, a);
        try entities.setComponent(a, player_id, ecs.Component.Physics{ .pos = .{ .x = 3, .y = 5 } });

        return Level{
            .name = "harry truman",
            .ecs = entities,
            .map = world_map,
        };
    }
};
