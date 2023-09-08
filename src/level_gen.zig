//const std = @import("std");
//const level = @import("level.zig");
//const tile = @import("tiles.zig");
//const file = @import("file_utils.zig");
//const menu = @import("menu.zig");
//
//const ray = @cImport({
//    @cInclude("raylib.h");
//    @cInclude("raygui.h");
//    @cInclude("style_dark.h");
//});
//
////stores entries in config files
//const Record = struct {
//    name: []const u8,
//    weight: u32,
//};
//
////
////
////========BIOME IMPLEMENTAION========
//pub const Biome = struct {
//    name: []const u8,
//    tiles: []Record,
//    structures: []Record,
//};
//
//pub const BiomeState = std.StringHashMap(Biome);
//
//pub fn initBiomeState(a: std.mem.Allocator) !BiomeState {
//    file.readConfig(a, []Biome, "biomes.json");
//}
//
////
////
////========LEVEL GEN========
//pub const LevelGenOptions = struct {
//    name
//    biomes: []Record,
//    density: f64,
//};
//
//pub fn generateLevel(a: std.mem.Allocator, options: LevelGenOptions) level.Level {
//
//
//
////pub const Level = struct {
////    id: []const u8,
////    entities: entity.EntityState,
////    map: map.MapState,
////    exits: []exit.Exit,
////};
//}
//
////
////
////========SAVE GEN=======
//
//pub const NewSaveOptions = struct {
//    name: []u8,
//};
//
//pub fn createNewSave(a: std.mem.Allocator, options: NewSaveOptions) !void {
//    try file.createSaveDir(a, options.name);
//    const first_level = generateLevel();
//    file.writeLevel(a, first_level, options.name, "first_level");
//}
