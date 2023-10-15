const std = @import("std");
const texture = @import("textures.zig");
const tile = @import("tiles.zig");
const level = @import("level.zig");
const options = @import("options.zig");
const Allocator = std.mem.Allocator;
const perlin = @cImport({
    @cInclude("perlin.c");
});

const ray = @cImport({
    @cInclude("raylib.h");
});

pub fn Grid(comptime T: type) type {
    return struct {
        items: [][]?T,
        neighbor_list: [9]T,

        pub fn init(a: Allocator, width: u32, height: u32) !@This() {
            var base = try a.alloc([]?T, width);
            for (base) |*item| {
                item.* = try a.alloc(?T, height);
                @memset(item.*, null);
            }
            return @This(){
                .items = base,
                .neighbor_list = undefined,
            };
        }

        pub fn clear(self: *@This()) void {
            for (self.items) |*item| {
                @memset(item.*, null);
            }
        }

        pub fn deinit(self: *const @This(), a: Allocator) void {
            a.free(self.items);
        }

        pub fn isValidIndex(self: *@This(), x: u32, y: u32) bool {
            return x > 0 and x < self.items.len and y > 0 and y < self.items[x].len;
        }

        pub fn find_neighbors(self: *@This(), search_x: u32, search_y: u32) []T {
            var len = 0;

            for (0..3) |x_offset| {
                for (0..3) |y_offset| {
                    const x = search_x + x_offset - 1;
                    const y = search_y + y_offset - 1;

                    if (x == search_x or y == search_y or !self.isValidIndex(x, y)) {
                        continue;
                    }

                    if (self.items[x][y]) |item| {
                        self.neighbor_list[len] = item;
                    }
                }
            }
            return self.neighbor_list[0..len];
        }
    };
}

pub const IdList = struct {
    pub const cap = 16;
    ids: [cap]u32 = undefined,
    len: u32 = 0,
};

pub const MapState = struct {
    tile_grid: Grid(u8),
    collision_grid: Grid(bool),
    width: usize,
    height: usize,

    pub fn generate(a: std.mem.Allocator, tile_state: tile.TileState, opt: level.LevelGenOptions) !@This() {
        var tile_grid = try Grid(u8).init(a, opt.width, opt.height);
        var collision_grid = try Grid(bool).init(a, opt.width, opt.height);

        const floor = tile_state.get("cave_floor").?;
        const wall = tile_state.get("cave_wall").?;

        for (0..opt.width) |x| {
            for (0..opt.height) |y| {
                if (perlin.perlin2d(@floatFromInt(x), @floatFromInt(y), 0.1, 4) > 0.5) {
                    tile_grid.items[x][y] = floor;
                    collision_grid.items[x][y] = false;
                } else {
                    tile_grid.items[x][y] = wall;
                    collision_grid.items[x][y] = true;
                }
            }
        }
        return .{
            .tile_grid = tile_grid,
            .collision_grid = collision_grid,
            .width = opt.width,
            .height = opt.height,
        };
    }

    pub fn deinit(self: *const @This(), a: std.mem.Allocator) void {
        self.tile_grid.deinit(a);
    }

    pub fn render(self: *const @This(), tiles: tile.TileState, opt: options.Render) void {
        for (0..self.tile_grid.items.len) |x| {
            for (0..self.tile_grid.items[x].len) |y| {
                if (self.tile_grid.items[x][y]) |id| {
                    const grid_x = @as(f32, @floatFromInt(x)) * opt.grid_spacing;
                    const grid_y = @as(f32, @floatFromInt(y)) * opt.grid_spacing;
                    const tile_texture: ray.Texture2D = tiles.tiles[id].texture;
                    ray.DrawTextureEx(tile_texture, .{ .x = grid_x, .y = grid_y }, 0, opt.scale, ray.RAYWHITE);
                }
            }
        }
    }
};

//pub const MapState = struct {
////    collision_grid: Grid(IdList) = undefined,
// //   tile_grid: Grid(tile.TileConfig) = undefined,
//    grid: Grid(usize),
//
//    pub fn generate(a: std.mem.Allocator, assets: level.Assets, opt: level.LevelGenOptions) !@This() {
//
//
//  //      const floor = tile.TileConfig{ .id = assets.tile_state.get("cave_floor") orelse 0 };
//  //      const wall = tile.TileConfig{ .id = assets.tile_state.get("cave_wall") orelse 0 };
//  //      for (0..opt.width) |x| {
//  //          for (0..opt.height) |y| {
//  //              if (x == 0 or y == 0) {
//  //                  tile_grid.items[x][y] = wall;
//  //              } else {
//  //                  tile_grid.items[x][y] = floor;
//  //              }
//  //          }
//  //      }
//  //
//  //      var tile_grid = try Grid(tile.TileConfig).init(a, opt.width, opt.height);
//
//  //      return @This(){
//  //          //TODO update this
//  //          .collision_grid = try Grid(IdList).init(a, opt.width, opt.height),
//  //          .tile_grid = tile_grid,
//  //      };
//
//    }
//
//    pub fn render(self: *const @This(), tiles: tile.TileState, options: texture.RenderOptions) void {
//        for (0..self.tile_grid.items.len) |x| {
//            for (0..self.tile_grid.items[x].len) |y| {
//                if (self.tile_grid.items[x][y]) |config| {
//                    tiles.render(config, .{ .x = @as(f32, @floatFromInt(x)) * options.grid_spacing, .y = @as(f32, @floatFromInt(y)) * options.grid_spacing }, options);
//                }
//            }
//        }
//    }
//};
