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

inline fn getCorners(r: ray.Rectangle) [4]ray.Vector2 {
    return [4]ray.Vector2{
        .{ .x = r.x, .y = r.y },
        .{ .x = r.x + r.width, .y = r.y },
        .{ .x = r.x, .y = r.y + r.height },
        .{ .x = r.x + r.width, .y = r.y + r.height },
    };
}

const CellularAutomataOptions = struct {
    chance_to_start_as_wall: f32 = 0.15,
    num_simulation_steps: usize = 5,
    birth_threshhold: usize = 5, //number of neighbors for a floor to become a wall
    death_threshhold: usize = 4,
};

pub fn cellularAutomata(a: std.mem.Allocator, rng: std.rand.Random, width: usize, height: usize, opt: CellularAutomataOptions) !Grid(tile.Category) {
    const result = try Grid(tile.Category).init(a, width, height, .floor);

    //initialize grid
    for (result.items) |*cell| {
        if (rng.floatNorm(f32) < opt.chance_to_start_as_wall) {
            cell.* = .wall;
        } else {
            cell.* = .floor;
        }
    }

    //std.debug.print("Initialized grid\n\n", .{});
    //result.printContents();

    const temp = try Grid(tile.Category).init(a, width, height, .floor);
    //do simulation step
    for (0..opt.num_simulation_steps) |_| {

        //iterate over cells
        for (0..result.width) |x| {
            for (0..result.height) |y| {

                //count neighbors
                const count = result.countMatchingNearby(x, y, .wall);

                //update temp
                if (result.get(x, y) == .wall) {
                    if (count < opt.death_threshhold) {
                        temp.at(x, y).?.* = .floor;
                    } else {
                        temp.at(x, y).?.* = .wall;
                    }
                } else if (result.get(x, y) == .floor) {
                    if (count > opt.birth_threshhold) {
                        temp.at(x, y).?.* = .wall;
                    } else {
                        temp.at(x, y).?.* = .floor;
                    }
                }
            }
        }

        //update result with temp calculated values
        @memcpy(result.items, temp.items);

        //std.debug.print("\nAfter step\n", .{});
        //result.printContents();
    }

    return result;
}

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

        pub fn getCache(self: *const @This()) []const ?usize {
            return &self.entity_location_cache;
        }

        pub fn clearCache(self: *@This()) void {
            @memset(&self.entity_location_cache, null);
        }
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
        //const perlin_image = ray.GenImagePerlinNoise(@intCast(opt.width), @intCast(opt.height), 0, 0, 1);
        //defer ray.UnloadImage(perlin_image);
        //const perlin = ray.LoadImageColors(perlin_image);
        var rng = std.rand.DefaultPrng.init(opt.seed);
        const template = try cellularAutomata(a, rng.random(), opt.width, opt.height, .{});

        var grid = try Grid(CellData).init(a, opt.width, opt.height, .{});

        for (0..opt.width) |x| {
            for (0..opt.height) |y| {
                if (template.get(x, y) == .floor) {
                    grid.at(x, y).?.tile = tile_state.get("cave_floor").?;
                } else {
                    grid.at(x, y).?.tile = tile_state.get("cave_wall").?;
                }
            }
        }

        var result = @This(){ .grid = grid };
        try result.deriveTileRenderers();
        return result;
    }

    pub fn deinit(self: *const @This(), a: std.mem.Allocator) void {
        self.tile_grid.deinit(a);
    }

    pub fn renderMain(self: *const @This(), a: std.mem.Allocator, window_manager: *const anime.WindowManager, ecs: *ECS) void {
        const bounds = window_manager.getVisibleBounds(a, ecs, self);

        for (bounds.min_x..bounds.max_x) |x| {
            for (bounds.min_y..bounds.max_y) |y| {
                self.grid.at(x, y).?.renderer.renderMain(window_manager, .{
                    .x = @floatFromInt(x),
                    .y = @floatFromInt(y),
                });
            }
        }
    }

    pub fn renderBorders(self: *const @This(), a: std.mem.Allocator, window_manager: *const anime.WindowManager, ecs: *ECS) void {
        const bounds = window_manager.getVisibleBounds(a, ecs, self);

        for (bounds.min_x..bounds.max_x) |x| {
            for (bounds.min_y..bounds.max_y) |y| {
                self.grid.at(x, y).?.renderer.renderBorders(window_manager, .{
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
