const std = @import("std");
const level = @import("level.zig");
const tile = @import("tiles.zig");
const file = @import("file_utils.zig");

//stores entries in config files
const Record = struct {
    name: []const u8,
    weight: u32,
};

//
//
//========BIOME IMPLEMENTAION========
pub const Biome = struct {
    name: []const u8,
    tiles: []Record,
    structures: []Record,
};

pub const BiomeState = std.StringHashMap(Biome);

pub fn initBiomeState(a: std.mem.Allocator) !BiomeState {
    file.readConfig(a, []Biome, "biomes.json");
}

//
//
//========LEVEL GEN========
pub const LevelGenOptions = struct {
    biomes: []Record,
    density: f64,
};

pub fn generateLevel(a: std.mem.Allocator, options: LevelGenOptions) level.Level {
    _ = a;
    _ = options;
}
