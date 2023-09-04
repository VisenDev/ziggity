const std = @import("std");
const entity = @import("entity.zig");
const map = @import("map.zig");
const texture = @import("textures.zig");
const tile = @import("tiles.zig");
const exit = @import("exit.zig");
const json = std.json;

pub const Assets = struct {
    tile_state: tile.TileState,
    texture_state: texture.TextureState,
};

pub const Level = struct {
    id: []const u8,
    entities: entity.EntityState,
    map: map.MapState,
    exits: []exit.Exit,
};

test "json" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const level = Level.init(gpa.allocator());
    const string = try json.stringifyAlloc(gpa.allocator(), level, .{});
    std.debug.print("JSON: \n\n{s}\n\n\n", .{string});
}
