const std = @import("std");
const entity = @import("components.zig");
const map = @import("map.zig");
const texture = @import("textures.zig");
const tile = @import("tiles.zig");
const file = @import("file_utils.zig");
const config = @import("config.zig");
const json = std.json;

pub const GameState = struct {
    assets: Assets,
    key_bindings: config.KeyBindings,
    active_level: Level,
    player_id: usize,
    save_id: []u8,
};

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
};

pub const Exit = struct {
    x: u32,
    y: u32,
    destination_id: []const u8,
};

pub const Level = struct {
    pub const Record = struct { name: []const u8, weight: u32 };
    pub const GenOptions = struct { name: []const u8, biomes: []const Record, density: f64 = 0.4, width: u32 = 100, height: u32 = 100 };

    name: []const u8,
    entities: entity.EntityState,
    map: map.MapState,
    exits: []const Exit,

    pub fn generate(a: std.mem.Allocator, options: GenOptions) !Level {
        var entities = try entity.EntityState.init(a);
        const world_map = try map.MapState.init(a);
        const exits = [_]Exit{.{ .x = 5, .y = 5, .destination_id = "first_level" }};

        return Level{ .name = options.name, .entities = entities, .map = world_map, .exits = &exits };
    }

    pub fn update(self: Level, a: std.mem.Allocator, dt: f32) !void {
        _ = self;
        _ = a;
        _ = dt;
    }

    pub fn render(self: Level, scale: f32) !void {
        _ = self;
        _ = scale;
    }
};

test "json" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const level = Level.init(gpa.allocator());
    const string = try json.stringifyAlloc(gpa.allocator(), level, .{});
    std.debug.print("JSON: \n\n{s}\n\n\n", .{string});
}
