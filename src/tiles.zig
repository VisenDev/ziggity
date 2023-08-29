const std = @import("std");
const ray = @cImport({
    @cInclude("raylib.h");
});
const json = std.json;
const tex = @import("textures.zig");

pub const Tile = struct {
    texture: ray.Texture2D,
    side: ray.Texture2D,
    top: ray.Texture2D,
};

const TileJSON = struct {
    name: []const u8,
    category: enum { wall, floor },
    texture: []const u8,
    side_texture: []const u8,
    top_texture: []const u8,
};

pub const TileConfig = struct {
    id: u8,
    core: bool = true, //render the core of the texture
    left: bool = false, //render the left border ...
    right: bool = false,
    top: bool = false,
};

pub const TileState = struct {
    tiles: []Tile,

    pub fn render(self: *@This(), config: TileConfig, x: u32, y: u32, scale: f32) void {
        _ = self;
        _ = config;
        _ = x;
        _ = y;
        _ = scale;
    }

    pub fn init(a: std.mem.Allocator, texture_state: tex.TextureState) !@This() {
        const string = try std.fs.cwd().readFileAlloc(a, "config/tiles.json", 2048);
        defer a.free(string);

        const entries = (try json.parseFromSlice([]TileJSON, a, string, .{})).value;
        var result = try a.alloc(Tile, entries.len);

        for (entries, 0..) |entry, i| {
            result[i].texture = texture_state.get(entry.texture);
            result[i].side = texture_state.get(entry.side_texture);
            result[i].top = texture_state.get(entry.top_texture);
        }

        return .{ .tiles = result };
    }
};

//
//const TileTextureRecord = struct {
//    weight: u32,
//    name: []const u8,
//};
//
//pub const TileMechanics = enum { wall, floor, water };
//
//const TileRecord = struct {
//    name: []const u8,
//    mechanics: TileMechanics,
//    texture: []TileTextureRecord,
//    side_border_texture: []const u8,
//    top_border_texture: []const u8,
//};
//
//pub const Tile = struct {
//    name: []const u8,
//    mechanics: TileMechanics,
//    texture: []ray.Texture2D,
//    side_border: []ray.Texture2D,
//    top_border: []ray.Texture2D,
//};
//
//pub const BorderConfig = packed struct {
//    top_left: u1,
//    top_center: u1,
//    top_right: u1,
//    left: u1,
//    right: u1,
//    bottom_left: u1,
//    bottom_center: u1,
//    bottom_right: u1,
//};
//
//pub const TileConfig = struct {
//    id: u16,
//    borders: BorderConfig,
//    border_only: bool,
//};
//
//pub const TileState = struct {
//    tiles: []Tile,
//
//    pub fn render(self: *@This(), config: TileConfig, x: usize, y: usize, scale: f32) void {
//        _ = self;
//        _ = config;
//        _ = x;
//        _ = y;
//        _ = scale;
//    }
//};
//
//pub fn loadTiles(a: std.mem.Allocator, t: tex.TextureState) ![]Tile {
//    const string = try std.fs.cwd().readFileAlloc(a, "config/tiles.json", 2048);
//    defer a.free(string);
//
//    const data = try json.parseFromSlice([]TileRecord, a, string, .{});
//
//    var result = try a.alloc(Tile, data.value.len);
//    for (data.value, 0..) |item, i| {
//
//        //get textures
//        var textures = try a.alloc(ray.Texture2D, item.texture.len);
//        for (item.texture, 0..) |name, j| {
//            textures[j] = t.get(name.name);
//        }
//
//        var side_border_textures = try a.alloc(ray.Texture2D, item.side_border_texture.len);
//        for (item.side_border_texture, 0..) |name, j| {
//            side_border_textures[j] = t.get(name.name);
//        }
//
//        var top_border_textures = try a.alloc(ray.Texture2D, item.top_border_texture.len);
//        for (item.side_border_texture, 0..) |name, j| {
//            side_border_textures[j] = t.get(name.name);
//        }
//
//        result[i] = Tile{
//            .name = item.name,
//            .mechanics = item.mechanics,
//            .texture = textures,
//            .side_border = side_border_textures,
//            .top_border = top_border_textures,
//        };
//    }
//
//    return result;
//}
//
////test "load" {
////    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
////    const a = gpa.allocator();
////    var tiles = try loadTiles(a);
////    std.debug.print("{any}\n", .{tiles});
////}
