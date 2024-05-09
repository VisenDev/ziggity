const std = @import("std");
const camera = @import("camera.zig");
const Component = @import("components.zig");
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
//const Borders = [3][3]bool;

pub const Char = struct {
    pub const empty = ' ';
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

inline fn getCorners(r: ray.Rectangle) [4]ray.Vector2 {
    return [4]ray.Vector2{
        .{ .x = r.x, .y = r.y },
        .{ .x = r.x + r.width, .y = r.y },
        .{ .x = r.x, .y = r.y + r.height },
        .{ .x = r.x + r.width, .y = r.y + r.height },
    };
}

inline fn split(a: std.mem.Allocator, str: []const u8) !std.ArrayList([]const u8) {
    const trimmed = std.mem.trim(u8, std.mem.trim(u8, std.mem.trim(u8, str, "\n"), " "), "\n");
    var iter = std.mem.splitScalar(u8, trimmed, '\n');

    var result = std.ArrayList([]const u8).init(a);

    var len: ?usize = null;

    while (iter.next()) |row| {
        const truncated = std.mem.trim(u8, row, " ");
        std.debug.print("row: {s}\n", .{truncated});

        if (len == null) {
            len = truncated.len;
        } else if (truncated.len != len.?) {
            std.debug.print("len: {?}\ntrunclen: {}\ntrunc: {s}\n\n", .{ len, truncated.len, truncated });
            return error.inconsistent_substr_lengths;
        }
        try result.append(truncated);
    }

    return result;
}

pub const MapState = struct {
    tile_grid: Grid(tile.Tile),
    animation_grid: Grid(tile.TileRenderer),
    collision_grid: Grid(bool),
    width: usize,
    height: usize,

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
        if (self.collision_grid.get(x, y)) |collision| {
            return collision.*;
        } else return false;
    }
    //
    //    pub fn generate(a: std.mem.Allocator, tile_state: tile.TileState, opt: level.LevelGenOptions) !@This() {
    //        var tile_grid = try Grid(tile.Tile).init(a, opt.width, opt.height, undefined);
    //        var collision_grid = try Grid(bool).init(a, opt.width, opt.height, false);
    //        var animation_grid = try Grid(anime.AnimationPlayer).init(a, opt.width, opt.height, undefined);
    //
    //        for (0..opt.width) |x| {
    //            for (0..opt.height) |y| {
    //                if (perlin.perlin2d(@floatFromInt(x), @floatFromInt(y), 0.1, 4) > 0.5) {
    //                    tile_grid.items[x][y] = tile_state.get("cave_floor").?;
    //                    collision_grid.items[x][y] = false;
    //
    //                    animation_grid.items[x][y] = .{ .animation_name = "cave_floor" };
    //                } else {
    //                    tile_grid.items[x][y] = tile_state.get("cave_wall").?;
    //                    collision_grid.items[x][y] = true;
    //
    //                    animation_grid.items[x][y] = .{ .animation_name = "cave_wall" };
    //                }
    //            }
    //        }
    //
    //        return .{
    //            .tile_grid = tile_grid,
    //            .collision_grid = collision_grid,
    //            .animation_grid = animation_grid,
    //            .width = opt.width,
    //            .height = opt.height,
    //        };
    //    }

    pub fn generateFromString(a: std.mem.Allocator, tile_state: tile.TileState, string: []const u8) !@This() {
        std.debug.print("string: \n\n{s}\n", .{string});

        const strs = try split(a, string);

        const height = strs.items.len;
        const width = strs.items[0].len;

        var tile_grid = try Grid(tile.Tile).init(a, width, height, undefined);
        var collision_grid = try Grid(bool).init(a, width, height, false);
        var animation_grid = try Grid(tile.TileRenderer).init(a, width, height, undefined);

        //set tiles
        for (strs.items, 0..) |row, y| {
            for (row, 0..) |ch, x| {
                try tile_grid.set(a, x, y, switch (ch) {
                    Char.natural_wall => tile_state.get("cave_wall").?,
                    else => tile_state.get("cave_floor").?,
                });
            }
        }

        //set collisions
        //TODO remove collision grid
        for (0..tile_grid.getWidth()) |x| {
            for (0..tile_grid.getHeight()) |y| {
                try collision_grid.set(a, x, y, tile_grid.get(x, y).?.category == .wall);
            }
        }

        for (0..tile_grid.getWidth()) |x| {
            for (0..tile_grid.getHeight()) |y| {
                const animation = tile.TileRenderer.init(tile_grid.getNeighborhood(x, y));
                try animation_grid.set(a, x, y, animation);
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
        _ = tile_state;

        for (0..self.animation_grid.items.len) |x| {
            for (0..self.animation_grid.items[x].len) |y| {
                self.animation_grid.items[x][y].render(animation_state, .{
                    .x = @floatFromInt(x),
                    .y = @floatFromInt(y),
                });
            }
        }
    }
};
