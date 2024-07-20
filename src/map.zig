const std = @import("std");
const ECS = @import("ecs.zig").ECS;
const camera = @import("camera.zig");
const Component = @import("components.zig");
const anime = @import("animation.zig");
const texture = @import("textures.zig");
const tile = @import("tiles.zig");
const level = @import("level.zig");
const options = @import("options.zig");
const Allocator = std.mem.Allocator;
const Grid = @import("grid.zig").Grid;

const ray = @cImport({
    @cInclude("raylib.h");
});

fn tof32(input: anytype) f32 {
    return @floatFromInt(input);
}

//pub const IdList = struct {
//    pub const cap = 16;
//    ids: [cap]u32 = [1]u32{0} ** cap,
//    len: u32 = 0,
//};
//const Borders = [3][3]bool;

//pub const Char = struct {
//    pub const empty = ' ';
//    pub const natural_wall = '#';
//    pub const natural_floor = '.';
//    pub const pit = ':';
//    pub const structure_wall = '%';
//    pub const structure_floor = '-';
//    pub const liquid = '~';
//    pub const bridge = '=';
//    pub const door = '+';
//    pub const treasure = '$';
//    pub const boss = 'B';
//};
//
//const lvl1 =
//    \\#########
//    \\#....####
//    \\##.....##
//    \\###.....#
//    \\#%%%%+%%%
//    \\#%------%
//    \\#%---B--%
//    \\#%------%
//    \\#%------%
//    \\#%%%%+%%%
//    \\###..$.##
//    \\####..###
//    \\#########
//;

inline fn getCorners(r: ray.Rectangle) [4]ray.Vector2 {
    return [4]ray.Vector2{
        .{ .x = r.x, .y = r.y },
        .{ .x = r.x + r.width, .y = r.y },
        .{ .x = r.x, .y = r.y + r.height },
        .{ .x = r.x + r.width, .y = r.y + r.height },
    };
}

//inline fn split(a: std.mem.Allocator, str: []const u8) !std.ArrayList([]const u8) {
//    const trimmed = std.mem.trim(u8, std.mem.trim(u8, std.mem.trim(u8, str, "\n"), " "), "\n");
//    var iter = std.mem.splitScalar(u8, trimmed, '\n');
//
//    var result = std.ArrayList([]const u8).init(a);
//
//    var len: ?usize = null;
//
//    while (iter.next()) |row| {
//        const truncated = std.mem.trim(u8, row, " ");
//        std.debug.print("row: {s}\n", .{truncated});
//
//        if (len == null) {
//            len = truncated.len;
//        } else if (truncated.len != len.?) {
//            std.debug.print("len: {?}\ntrunclen: {}\ntrunc: {s}\n\n", .{ len, truncated.len, truncated });
//            return error.inconsistent_substr_lengths;
//        }
//        try result.append(truncated);
//    }
//
//    return result;
//}
//

pub const MapState = struct {
    grid: Grid(CellData),
    pub const CellData = struct {
        tile: tile.Tile = undefined,
        renderer: tile.TileRenderer = undefined,
        entity_location_cache: [cache_capacity]?usize = .{null} ** cache_capacity,
        const cache_capacity = 4;

        pub fn appendCache(self: *@This(), entity_id: usize) void {
            if (self.entity_location_cache[0] != entity_id) {
                for (0..cache_capacity - 1) |i| {
                    self.entity_location_cache[cache_capacity - 1 - i] = self.entity_location_cache[cache_capacity - 2 - i];
                }
                self.entity_location_cache[0] = entity_id;
            }
        }
        //entity_location_cache: CacheType = std.math.maxInt(CacheType),
        //cache_len: usize = 0,

        //const cache_capacity = 4;
        //const CacheType = @Type(.{ .Int = .{ .signedness = .unsigned, .bits = @sizeOf(usize) * cache_capacity * 8 } });

        //fn accessCacheIndex(self: *const @This(), index: u8) usize {
        //    const resultValue = (self.entity_location_cache >> (index * @sizeOf(usize))) & std.math.maxInt(usize);
        //    return @intCast(resultValue);
        //}

        pub fn getCache(self: *const @This()) []const ?usize {
            return &self.entity_location_cache;
        }

        pub fn clearCache(self: *@This()) void {
            @memset(&self.entity_location_cache, null);
        }

        //    const ptr: *const [4]usize = @ptrCast(&self.entity_location_cache);
        //    return ptr.*[cache_capacity - 1 .. cache_capacity];
        //}

    };

    pub fn checkCollision(self: *const @This(), hitbox: ray.Rectangle) bool {
        for (getCorners(hitbox)) |point| {
            if (self.checkPointCollision(point)) {
                return true;
            }
        }
        return false;
    }

    pub fn checkPointCollision(self: *const @This(), point: ray.Vector2) bool {
        const x: usize = @intFromFloat(@max(@floor(point.x), 0));
        const y: usize = @intFromFloat(@max(@floor(point.y), 0));
        if (self.grid.at(x, y)) |cell_data| {
            return cell_data.tile.category == .wall;
        } else return false;
    }

    pub fn deriveTileRenderers(self: *@This()) !void {
        for (0..self.grid.width) |x| {
            for (0..self.grid.height) |y| {
                self.grid.at(x, y).?.renderer = tile.TileRenderer.init(self.grid.findNearbyCells(x, y));
            }
        }
    }

    pub fn generate(a: std.mem.Allocator, tile_state: *const tile.TileState, opt: level.LevelGenOptions) !@This() {
        const perlin_image = ray.GenImagePerlinNoise(@intCast(opt.width), @intCast(opt.height), 0, 0, 1);
        defer ray.UnloadImage(perlin_image);
        const perlin = ray.LoadImageColors(perlin_image);

        var grid = try Grid(CellData).init(a, opt.width, opt.height, .{});

        for (0..opt.width) |x| {
            for (0..opt.height) |y| {
                const sample_value = perlin[x * opt.width + y].r;
                if (sample_value > 50) {
                    grid.at(x, y).?.tile = tile_state.get("cave_floor").?;
                    //grid.at(x, y).?.collision = false;

                    //grid.at(x, y).?.renderer = .{ .animation_name = "cave_floor" };
                } else {
                    grid.at(x, y).?.tile = tile_state.get("cave_wall").?;
                    //grid.at(x, y).?.collision = false;
                    //animation_grid.items[x][y] = .{ .animation_name = "cave_wall" };
                }
            }
        }

        var result = @This(){ .grid = grid };
        try result.deriveTileRenderers();
        return result;
    }

    // pub fn generateFromString(a: std.mem.Allocator, tile_state: tile.TileState, string: []const u8) !@This() {
    //     std.debug.print("string: \n\n{s}\n", .{string});

    //     const strs = try split(a, string);

    //     const height = strs.items.len;
    //     const width = strs.items[0].len;

    //     var tile_grid = try Grid(tile.Tile).init(a, width, height, undefined);
    //     var collision_grid = try Grid(bool).init(a, width, height, false);
    //     var animation_grid = try Grid(tile.TileRenderer).init(a, width, height, undefined);

    //     //set tiles
    //     for (strs.items, 0..) |row, y| {
    //         for (row, 0..) |ch, x| {
    //             try tile_grid.set(a, x, y, switch (ch) {
    //                 Char.natural_wall => tile_state.get("cave_wall").?,
    //                 else => tile_state.get("cave_floor").?,
    //             });
    //         }
    //     }

    //     //set collisions
    //     //TODO remove collision grid
    //     for (0..tile_grid.getWidth()) |x| {
    //         for (0..tile_grid.getHeight()) |y| {
    //             try collision_grid.set(a, x, y, tile_grid.get(x, y).?.category == .wall);
    //         }
    //     }

    //     for (0..tile_grid.getWidth()) |x| {
    //         for (0..tile_grid.getHeight()) |y| {
    //             const animation = tile.TileRenderer.init(tile_grid.getNeighborhood(x, y));
    //             try animation_grid.set(a, x, y, animation);
    //         }
    //     }

    //     return .{
    //         .tile_grid = tile_grid,
    //         .collision_grid = collision_grid,
    //         .animation_grid = animation_grid,
    //         .width = width,
    //         .height = height,
    //     };
    // }

    pub fn deinit(self: *const @This(), a: std.mem.Allocator) void {
        self.tile_grid.deinit(a);
    }

    pub fn render(self: *const @This(), a: std.mem.Allocator, window_manager: *const anime.WindowManager, ecs: *ECS) void {
        const bounds = window_manager.getVisibleBounds(a, ecs, self);

        for (bounds.min_x..bounds.max_x) |x| {
            for (bounds.min_y..bounds.max_y) |y| {
                self.grid.at(x, y).?.renderer.render(window_manager, .{
                    .x = @floatFromInt(x),
                    .y = @floatFromInt(y),
                });
            }
        }
    }
};

test "cache" {
    var cell = MapState.CellData{};

    cell.appendCache(100);
    try std.testing.expect(cell.entity_location_cache[0] == 100);

    cell.appendCache(101);
    try std.testing.expect(cell.entity_location_cache[0] == 101);
    try std.testing.expect(cell.entity_location_cache[1] == 100);

    cell.appendCache(102);
    try std.testing.expect(cell.entity_location_cache[0] == 102);
    try std.testing.expect(cell.entity_location_cache[1] == 101);
    try std.testing.expect(cell.entity_location_cache[2] == 100);

    cell.appendCache(103);
    try std.testing.expect(cell.entity_location_cache[0] == 103);
    try std.testing.expect(cell.entity_location_cache[1] == 102);
    try std.testing.expect(cell.entity_location_cache[2] == 101);
    try std.testing.expect(cell.entity_location_cache[3] == 100);
}

//test "cache" {
//    var cell = MapState.CellData{};
//
//    cell.appendCache(100);
//    std.debug.print("{any}\n", .{cell.getCache()});
//    try std.testing.expect(cell.getCache()[0] == 100);
//
//    cell.appendCache(101);
//    try std.testing.expect(cell.getCache()[0] == 100);
//    try std.testing.expect(cell.getCache()[1] == 101);
//
//    cell.appendCache(102);
//    try std.testing.expect(cell.getCache()[0] == 100);
//    try std.testing.expect(cell.getCache()[1] == 101);
//    try std.testing.expect(cell.getCache()[2] == 102);
//
//    cell.appendCache(103);
//    try std.testing.expect(cell.getCache()[0] == 100);
//    try std.testing.expect(cell.getCache()[1] == 101);
//    try std.testing.expect(cell.getCache()[2] == 102);
//    try std.testing.expect(cell.getCache()[3] == 103);
//}
