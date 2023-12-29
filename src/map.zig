const std = @import("std");
const anime = @import("animation.zig");
const texture = @import("textures.zig");
const tile = @import("tiles.zig");
const level = @import("level.zig");
const options = @import("options.zig");
const Allocator = std.mem.Allocator;
const Grid = @import("grid.zig").Grid;

const perlin = @cImport({
    @cInclude("perlin.c");
});

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

pub const char = struct {
    pub const natural_wall = '#';
    pub const natural_floor = '.';
    pub const pit = ':';
    pub const structure_wall = '%';
    pub const structure_floor = '-';
    pub const liquid = '~';
    pub const bridge = '=';
    pub const door = '+';
    pub const treasure = '$';
    pub const boss = 'B';
};

const lvl1 =
    \\#########
    \\#....####
    \\##.....##
    \\###.....#
    \\#%%%%+%%%
    \\#%------%
    \\#%---B--%
    \\#%------%
    \\#%------%
    \\#%%%%+%%%
    \\###..$.##
    \\####..###
    \\#########
;

pub const MapState = struct {
    tile_grid: Grid(tile.Tile),
    animation_grid: Grid(anime.AnimationPlayer),
    collision_grid: Grid(bool),
    width: usize,
    height: usize,

    pub fn generate(a: std.mem.Allocator, tile_state: tile.TileState, opt: level.LevelGenOptions) !@This() {
        var tile_grid = try Grid(tile.Tile).init(a, opt.width, opt.height, undefined);
        var collision_grid = try Grid(bool).init(a, opt.width, opt.height, false);
        var animation_grid = try Grid(anime.AnimationPlayer).init(a, opt.width, opt.height, undefined);

        for (0..opt.width) |x| {
            for (0..opt.height) |y| {
                if (perlin.perlin2d(@floatFromInt(x), @floatFromInt(y), 0.1, 4) > 0.5) {
                    tile_grid.items[x][y] = tile_state.get("cave_floor").?;
                    collision_grid.items[x][y] = false;

                    animation_grid.items[x][y] = .{ .animation_name = "cave_floor" };
                } else {
                    tile_grid.items[x][y] = tile_state.get("cave_wall").?;
                    collision_grid.items[x][y] = true;

                    animation_grid.items[x][y] = .{ .animation_name = "cave_wall" };
                }
            }
        }

        return .{
            .tile_grid = tile_grid,
            .collision_grid = collision_grid,
            .animation_grid = animation_grid,
            .width = opt.width,
            .height = opt.height,
        };
    }

    pub fn generateFromString(a: std.mem.Allocator, tile_state: tile.TileState, string: []const u8) !@This() {
        const height = std.mem.count(u8, string, '\n');
        const width = std.mem.indexOfScalar(u8, string, '\n');

        var tile_grid = try Grid(tile.Tile).init(a, width, height, undefined);
        var collision_grid = try Grid(bool).init(a, width, height, false);
        var animation_grid = try Grid(anime.AnimationPlayer).init(a, width, height, undefined);

        for (0..width) |x| {
            for (0..height) |y| {
                switch (string[x * width + y]) {
                    char.natural_wall => {
                        tile_grid.items[x][y] = tile_state.get("cave_floor").?;
                        collision_grid.items[x][y] = false;

                        animation_grid.items[x][y] = .{ .animation_name = "cave_floor" };
                    },
                    else => {
                        tile_grid.items[x][y] = tile_state.get("cave_wall").?;
                        collision_grid.items[x][y] = true;

                        animation_grid.items[x][y] = .{ .animation_name = "cave_wall" };
                    },
                }
            }
        }

        return .{
            .tile_grid = tile_grid,
            .collision_grid = collision_grid,
            .animation_grid = animation_grid,
            .width = width,
            .height = height,
        };
    }

    pub fn deinit(self: *const @This(), a: std.mem.Allocator) void {
        self.tile_grid.deinit(a);
    }

    pub fn render(self: *const @This(), animation_state: *const anime.AnimationState, tile_state: *const tile.TileState) void {
        for (0..self.animation_grid.items.len) |x| {
            for (0..self.animation_grid.items[x].len) |y| {
                const grid_x = tof32(x * tile_state.resolution);
                const grid_y = tof32(y * tile_state.resolution);
                self.animation_grid.items[x][y].render(animation_state, .{ .x = grid_x, .y = grid_y });
            }
        }
    }
};
