const std = @import("std");
const MapState = @import("map.zig").MapState;
const Grid = @import("grid.zig").Grid;
const options = @import("options.zig");
const anime = @import("animation.zig");
const ray = @cImport({
    @cInclude("raylib.h");
});
const json = std.json;
const tex = @import("textures.zig");
const file = @import("file_utils.zig");
const Lua = @import("ziglua").Lua;

//const Borders = struct {
//const Row = struct { left: bool = false, middle: bool = false, right: bool = false };
//top: Row,
//center: Row,
//bottom: Row,
//};

//pub const TileRenderConfig = struct {
//    wall_top: bool = false,
//    wall_side_left: bool = false,
//    wall_side_right: bool = false,
//    main: bool = false,
//
//    pub fn generate(b: Borders) TileRenderConfig {
//        if (!b.center.middle) return .{ .main = true };
//
//        var result = TileRenderConfig{};
//        if (!b.top.middle) result.wall_top = true;
//        if (b.bottom.middle) result.wall_top = false;
//
//        if (b.bottom.left and b.bottom.right and b.bottom.middle and b.top.middle) {
//            return TileRenderConfig{ .wall_top = true };
//        }
//
//        return result;
//    }
//};

const Category = enum { wall, floor };

pub const Tile = struct {
    name: []const u8 = "",
    animations: struct {
        main: ?[]const u8 = null,
        border: struct {
            left: ?[]const u8 = null,
            right: ?[]const u8 = null,
            top: ?[]const u8 = null,
            bottom: ?[]const u8 = null,
        } = .{},
    } = .{},
    category: Category = .floor,

    pub fn eql(self: @This(), other: @This()) bool {
        return std.meta.eql(self, other);
    }
};

pub const TileRenderer = struct {
    main: ?anime.AnimationPlayer = null,
    border: struct {
        left: ?anime.AnimationPlayer = null,
        right: ?anime.AnimationPlayer = null,
        top: ?anime.AnimationPlayer = null,
        bottom: ?anime.AnimationPlayer = null,
    } = .{},

    const top_left = 0;
    const top_center = 1;
    const top_right = 2;
    const center_left = 3;
    const center = 4;
    const center_right = 5;
    const bottom_left = 6;
    const bottom_center = 7;
    const bottom_right = 8;

    fn eql(main: *MapState.CellData, neighbor: ?*MapState.CellData) bool {
        if (neighbor != null and neighbor.?.tile.eql(main.tile)) return true;
        return false;
    }

    pub fn init(neighbors: [9]?*MapState.CellData) TileRenderer {
        var result = TileRenderer{};

        const main = neighbors[center] orelse @panic("invalid center cell");
        result.main = .{ .animation_name = main.tile.animations.main.? };

        if (main.tile.category == .wall) {

            // Add top border if above tile is of a different type
            if (!eql(main, neighbors[top_center])) {
                result.border.top = .{ .animation_name = main.tile.animations.border.top.? };
            }

            // Add top border if below tile is of a different type
            if (!eql(main, neighbors[bottom_center])) {
                result.border.top = .{ .animation_name = main.tile.animations.border.top.? };
            }

            // Add side borders if cell to the left is of a different type
            if (!eql(main, neighbors[center_left])) {
                result.border.left = .{ .animation_name = main.tile.animations.border.right.? };
            }

            // Add side borders if cell to the right is of a different type
            if (!eql(main, neighbors[center_right])) {
                result.border.right = .{ .animation_name = main.tile.animations.border.right.? };
            }
            {
                // how many bordering cells share the same tile top
                var num_same_borders: usize = 0;

                // add to border similarity count
                if (eql(main, neighbors[bottom_right])) num_same_borders += 1;
                if (eql(main, neighbors[bottom_center])) num_same_borders += 1;
                if (eql(main, neighbors[bottom_left])) num_same_borders += 1;

                if (eql(main, neighbors[center_right])) num_same_borders += 1;
                if (eql(main, neighbors[center_left])) num_same_borders += 1;

                if (eql(main, neighbors[top_right])) num_same_borders += 1;
                if (eql(main, neighbors[top_center])) num_same_borders += 1;
                if (eql(main, neighbors[top_left])) num_same_borders += 1;

                if (num_same_borders >= 7) {
                    result.main = null;
                }
            }
        }

        return result;
    }

    pub fn render(self: *const TileRenderer, state: *const anime.WindowManager, pos: ray.Vector2) void {
        if (self.main) |main| {
            main.renderInWorld(state, pos, .{});
        }

        if (self.border.left) |left| {
            const adjusted: ray.Vector2 = .{ .x = pos.x - 0.5, .y = pos.y };
            left.renderInWorld(state, adjusted, .{});
        }

        if (self.border.right) |right| {
            const adjusted: ray.Vector2 = .{ .x = pos.x + 0.4, .y = pos.y };
            right.renderInWorld(state, adjusted, .{});
        }

        if (self.border.top) |top| {
            const adjusted: ray.Vector2 = .{ .x = pos.x, .y = pos.y - 0.5 };
            top.renderInWorld(state, adjusted, .{});
        }

        if (self.border.bottom) |bottom| {
            const adjusted: ray.Vector2 = .{ .x = pos.x, .y = pos.y + 0.40 };
            bottom.renderInWorld(state, adjusted, .{});
        }
    }

    pub fn update(self: *TileRenderer, opt: options.Update) void {
        //TODO update animations if applicable
        _ = self;
        _ = opt;
    }
};

pub const TileState = struct {
    tiles: std.StringHashMap(Tile),

    pub fn init(a: std.mem.Allocator, lua: *Lua) !@This() {
        var result = std.StringHashMap(Tile).init(a);
        errdefer result.deinit();

        var parsed = try file.readConfig([]Tile, lua, .tiles);
        defer parsed.deinit();

        for (parsed.value) |*tile| {

            //if no animations are provided, assume there is an animation that goes by the tile name
            //if (tile.animations == null) {
            //    tile.animations = .{};
            //    tile.animations.?.main = tile.name;
            //}
            try result.put(tile.name, tile.*);
        }

        return .{ .tiles = result };
    }

    pub fn deinit(self: *@This()) void {
        self.tiles.deinit();
    }

    pub fn get(self: *const @This(), name: []const u8) ?Tile {
        const found = self.tiles.get(name);
        //std.debug.print("found tile {s} of value {any}\n", .{ name, found });
        return found;
    }
};

//pub const Tile = struct {
//    texture: ray.Texture2D,
//    category: Category,
//};
//
//const TileJSON = struct {
//    name: []const u8,
//    category: Category,
//    texture: []const u8,
//};
//
//pub const TileState = struct {
//    tiles: []Tile,
//    name_index: std.StringHashMap(u8),
//
//    pub inline fn get(self: *const @This(), name: []const u8) ?u8 {
//        return self.name_index.get(name);
//    }
//
//    pub fn init(a: std.mem.Allocator, texture_state: tex.TextureState) !@This() {
//        //TODO add configuration details hashing to remember which config was used
//
//        var name_index = std.StringHashMap(u8).init(a);
//        const entries_json = try file.readConfig([]TileJSON, a, "tiles.json");
//        const entries = entries_json.value;
//        var result = try a.alloc(Tile, entries.len);
//
//        for (entries, 0..) |entry, i| {
//            result[i].texture = texture_state.get(entry.texture);
//            result[i].category = entry.category;
//            try name_index.put(entry.name, @intCast(i));
//            std.debug.print("tile loaded: {}\n", .{entry});
//        }
//
//        return .{ .tiles = result, .name_index = name_index };
//    }
//
//    pub fn deinit(self: *const @This(), a: std.mem.Allocator) void {
//        a.free(self.tiles);
//        @constCast(self).name_index.deinit();
//    }
//};
//
////
////const TileTextureRecord = struct {
////    weight: u32,
////    name: []const u8,
////};
////
////pub const TileMechanics = enum { wall, floor, water };
////
////const TileRecord = struct {
////    name: []const u8,
////    mechanics: TileMechanics,
////    texture: []TileTextureRecord,
////    side_border_texture: []const u8,
////    top_border_texture: []const u8,
////};
////
////pub const Tile = struct {
////    name: []const u8,
////    mechanics: TileMechanics,
////    texture: []ray.Texture2D,
////    side_border: []ray.Texture2D,
////    top_border: []ray.Texture2D,
////};
////
////pub const BorderConfig = packed struct {
////    top_left: u1,
////    top_center: u1,
////    top_right: u1,
////    left: u1,
////    right: u1,
////    bottom_left: u1,
////    bottom_center: u1,
////    bottom_right: u1,
////};
////
////pub const TileConfig = struct {
////    id: u16,
////    borders: BorderConfig,
////    border_only: bool,
////};
////
////pub const TileState = struct {
////    tiles: []Tile,
////
////    pub fn render(self: *@This(), config: TileConfig, x: usize, y: usize, scale: f32) void {
////        _ = self;
////        _ = config;
////        _ = x;
////        _ = y;
////        _ = scale;
////    }
////};
////
////pub fn loadTiles(a: std.mem.Allocator, t: tex.TextureState) ![]Tile {
////    const string = try std.fs.cwd().readFileAlloc(a, "config/tiles.json", 2048);
////    defer a.free(string);
////
////    const data = try json.parseFromSlice([]TileRecord, a, string, .{});
////
////    var result = try a.alloc(Tile, data.value.len);
////    for (data.value, 0..) |item, i| {
////
////        //get textures
////        var textures = try a.alloc(ray.Texture2D, item.texture.len);
////        for (item.texture, 0..) |name, j| {
////            textures[j] = t.get(name.name);
////        }
////
////        var side_border_textures = try a.alloc(ray.Texture2D, item.side_border_texture.len);
////        for (item.side_border_texture, 0..) |name, j| {
////            side_border_textures[j] = t.get(name.name);
////        }
////
////        var top_border_textures = try a.alloc(ray.Texture2D, item.top_border_texture.len);
////        for (item.side_border_texture, 0..) |name, j| {
////            side_border_textures[j] = t.get(name.name);
////        }
////
////        result[i] = Tile{
////            .name = item.name,
////            .mechanics = item.mechanics,
////            .texture = textures,
////            .side_border = side_border_textures,
////            .top_border = top_border_textures,
////        };
////    }
////
////    return result;
////}
////
//////test "load" {
//////    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
//////    const a = gpa.allocator();
//////    var tiles = try loadTiles(a);
//////    std.debug.print("{any}\n", .{tiles});
////}
////
////
////pub const TileConfig = struct {
////    id: u8,
////    core: bool = true, //render the core of the texture
////    left: bool = false, //render the left border ...
////    right: bool = false,
////
////
////
//
////pub fn render(self: *const @This(), config: TileConfig, position: ray.Vector2, options: tex.RenderOptions) void {
////   // const tile = self.tiles[config.id];
////    _ = self; _ = config; _ = position
////
//
////    ////if (config.core) {
////    //    ray.DrawTextureEx(tile.texture, position, 0, options.scale, ray.RAYWHITE);
////    //}
//
////    //if (config.left) {
////    //    ray.DrawTextureEx(tile.side, position, 0, options.scale, ray.RAYWHITE);
////    //}
//
////    //if (config.right) {
////    //    ray.DrawTextureEx(tile.side, position, 0, options.scale, ray.RAYWHITE);
////    //}
//
////    //if (config.top) {
////    //    ray.DrawTextureEx(tile.top, position, 0, options.scale, ray.RAYWHITE);
////    //}
////    top: bool = false,
