const std = @import("std");
const entity = @import("entity.zig");
const map = @import("map.zig");
const json = std.json;

const entity_cap = 2048;

pub const Exit = struct {
    x: u32,
    y: u32,
    destination_id: []const u8,
};

pub const Level = struct {
    entities: entity.EntityState,
    map: map.MapState,
    exits: []Exit,

    pub fn init(a: std.mem.Allocator) !@This() {
        return .{
            .entities = try entity.EntityState.init(a),
            .map = try map.MapState.init(a),
            .exits = undefined,
        };
    }
};

pub fn loadFromFile(a: std.mem.Allocator, save_id: []const u8, level_id: []const u8) Level {
    const string = try std.fs.cwd().readFileAlloc(a, "saves/" ++ save_id ++ "/" ++ level_id ++ ".json", 2048);
    _ = string;
}

test "json" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const level: Level = undefined;
    //    const val = 10;
    const string = try json.stringifyAlloc(gpa.allocator(), level, .{});
    std.debug.print("JSON: \n\n{s}\n\n\n", .{string});
}

//define assets
