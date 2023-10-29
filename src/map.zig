const std = @import("std");
const anime = @import("animation.zig");
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

fn tof32(input: anytype) f32 {
    return @floatFromInt(input);
}

pub fn Grid(comptime T: type) type {
    return struct {
        items: [][]?T,
        neighbor_list: std.ArrayListUnmanaged(T),

        pub fn init(a: Allocator, width: u32, height: u32) !@This() {
            var base = try a.alloc([]?T, width);
            for (base) |*item| {
                item.* = try a.alloc(?T, height);
                @memset(item.*, null);
            }
            return @This(){
                .items = base,
                .neighbor_list = try std.ArrayListUnmanaged(T).initCapacity(a, 9),
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

            if (self.neighbor_list.items.len + self.neighbor_list.capacity < 9) {
                @panic("neighbor_list memory not allocated");
            }

            for (0..3) |x_offset| {
                for (0..3) |y_offset| {
                    const x = search_x + x_offset - 1;
                    const y = search_y + y_offset - 1;

                    if (x == search_x or y == search_y or !self.isValidIndex(x, y)) {
                        continue;
                    }

                    if (self.items[x][y]) |item| {
                        self.neighbor_list.items[len] = item;
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
    tile_grid: Grid(tile.Tile),
    animation_grid: Grid(anime.AnimationPlayer),
    collision_grid: Grid(bool),
    width: usize,
    height: usize,

    pub fn generate(a: std.mem.Allocator, tile_state: tile.TileState, opt: level.LevelGenOptions) !@This() {
        var tile_grid = try Grid(tile.Tile).init(a, opt.width, opt.height);
        var collision_grid = try Grid(bool).init(a, opt.width, opt.height);
        var animation_grid = try Grid(anime.AnimationPlayer).init(a, opt.width, opt.height);

        for (0..opt.width) |x| {
            for (0..opt.height) |y| {
                if (perlin.perlin2d(@floatFromInt(x), @floatFromInt(y), 0.1, 4) > 0.5) {
                    tile_grid.items[x][y] = tile_state.get("cave_floor").?;
                    collision_grid.items[x][y] = false;

                    //var player = anime.AnimationPlayer{ .animation_name = try a.alloc(u8, floor.animation.len) };
                    //std.mem.copy(u8, player.animation_name, floor.animation);
                    animation_grid.items[x][y] = .{ .animation_name = "cave_floor" };
                } else {
                    tile_grid.items[x][y] = tile_state.get("cave_wall").?;
                    collision_grid.items[x][y] = true;

                    //var player = anime.AnimationPlayer{ .animation_name = try a.alloc(u8, wall.animation.len) };
                    //std.mem.copy(u8, player.animation_name, wall.animation);
                    animation_grid.items[x][y] = .{ .animation_name = "cave_wall" };
                }
            }
        }

        //DEBUG
        for (0..opt.width) |x| {
            _ = x;
            for (0..opt.height) |y| {
                _ = y;
                //std.debug.print("{any}", .{tile_grid.items[x][y]});
            }
        }

        //std.debug.print("tile_grid {any}", .{tile_grid});

        try std.json.stringify(tile_grid, .{}, std.io.getStdOut().writer());
        const string = try std.json.stringifyAlloc(a, tile_grid, .{});
        std.debug.print("string: {s}", .{string});

        return .{
            .tile_grid = tile_grid,
            .collision_grid = collision_grid,
            .animation_grid = animation_grid,
            .width = opt.width,
            .height = opt.height,
        };
    }

    pub fn deinit(self: *const @This(), a: std.mem.Allocator) void {
        self.tile_grid.deinit(a);
    }

    pub fn render(self: *const @This(), animation_state: *const anime.AnimationState, tile_state: *const tile.TileState) void {
        for (0..self.animation_grid.items.len) |x| {
            for (0..self.animation_grid.items[x].len) |y| {
                if (self.animation_grid.items[x][y]) |*player| {
                    const grid_x = tof32(x * tile_state.resolution);
                    const grid_y = tof32(y * tile_state.resolution);
                    player.render(animation_state, .{ .x = grid_x, .y = grid_y });
                    //const tile_texture: ray.Texture2D = tiles.tiles[id].texture;
                    //ray.DrawTextureEx(tile_texture, .{ .x = grid_x, .y = grid_y }, 0, opt.scale, ray.RAYWHITE);

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
