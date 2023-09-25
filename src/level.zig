const std = @import("std");
const entity = @import("components.zig");
const map = @import("map.zig");
const texture = @import("textures.zig");
const tile = @import("tiles.zig");
const file = @import("file_utils.zig");
const config = @import("config.zig");
const player = @import("player.zig");
const json = std.json;

pub const Assets = struct {
    tile_state: tile.TileState,
    texture_state: texture.TextureState,

    pub fn init(a: std.mem.Allocator) !Assets {
        const texture_state = try texture.TextureState.init(a);
        return .{
            .tile_state = try tile.TileState.init(a, texture_state),
            .texture_state = texture_state,
        };
    }

    pub fn deinit(self: *const @This(), a: std.mem.Allocator) void {
        self.texture_state.deinit();
        self.tile_state.deinit(a);
    }
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
    biomes: []const Record,
    density: f64 = 0.4,
    width: u32 = 100,
    height: u32 = 100,
};

pub const Level = struct {
    name: []const u8,
    entities: *entity.EntityState,
    map: *map.MapState,
    exits: []const Exit,
    player_id: usize,

    pub fn generate(a: std.mem.Allocator, assets: Assets, options: LevelGenOptions) !Level {
        var entities = try a.create(entity.EntityState);
        entities.* = try entity.EntityState.init(a);
        const world_map = try a.create(map.MapState);
        world_map.* = try map.MapState.generate(a, assets, options);
        const exits = [_]Exit{.{ .x = 5, .y = 5, .destination_id = "first_level" }};

        const id = try entities.spawnEntity(a, .{
            .position = .{
                .pos = .{
                    .x = 10.0,
                    .y = 10.0,
                },
                .vel = .{
                    .x = 0.0,
                    .y = 0.0,
                },
            },
            .renderer = .{
                .texture_id = assets.texture_state.name_index.get("player").?,
            },
        });

        return Level{ .name = options.name, .entities = entities, .map = world_map, .exits = &exits, .player_id = id };
    }

    pub fn update(self: *Level, a: std.mem.Allocator, key: *config.KeyBindings, dt: f32) !void {
        _ = a;
        try player.updatePlayer(self.player_id, self.entities, key, dt);
    }

    pub fn render(self: Level, assets: Assets, options: texture.RenderOptions) !void {
        self.map.render(assets.tile_state, options);
        try self.entities.render(assets.texture_state, options);
    }

    pub fn deinit(self: *const @This(), a: std.mem.Allocator) void {
        self.entities.deinit(a);
        self.map.deinit(a);
    }
};

test "json" {
    //    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    //    const level = Level.init(gpa.allocator());
    //    const string = try json.stringifyAlloc(gpa.allocator(), level, .{});
    //    std.debug.print("JSON: \n\n{s}\n\n\n", .{string});
}
