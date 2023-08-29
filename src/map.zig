const std = @import("std");
const tile = @import("tiles.zig");
const Allocator = std.mem.Allocator;

pub const Level = struct {
    entity_state: ent.EntityState(entity_cap),
    map_state: map.MapState,
};
 pub const Assets = struct {
    texture_state: tex.TextureState,
    tile_state: tile.TileState,
 }

pub fn Grid(comptime T: type) type {
    return struct {
        items: [][]?T,
        neighbor_list: std.ArrayList(T),

        pub fn init(a: Allocator, width: u32, height: u32) !@This() {
            var base = try a.alloc([]?T, width);
            for (base) |*item| {
                item.* = try a.alloc(?T, height);
                @memset(item.*, null);
            }
            return @This(){
                .items = base,
                .neighbor_list = std.ArrayList(T).init(a),
            };
        }

        pub fn clear(self: *@This()) void {
            for (self.items) |*item| {
                @memset(item.*, null);
            }
        }

        pub fn deinit(self: *@This(), a: Allocator) void {
            for (self.items) |*item| {
                a.free(item);
            }
            a.free(self.items);
            self.neighbor_list.deinit();
        }

        pub fn isValidIndex(self: *@This(), x: u32, y: u32) bool {
            return x > 0 and x < self.items.len and y > 0 and y < self.items[x].len;
        }

        pub fn find_neighbors(self: *@This(), search_x: u32, search_y: u32) ![]T {
            self.neighbor_list.items.len = 0;

            for (0..3) |x_offset| {
                for (0..3) |y_offset| {
                    const x = search_x + x_offset - 1;
                    const y = search_y + y_offset - 1;

                    if (x == search_x or y == search_y or !self.isValidIndex(x, y)) {
                        continue;
                    }

                    if (self.items[x][y]) |item| {
                        try self.neighbor_list.append(item);
                    }
                }
            }
            return self.neighbor_list.items;
        }
    };
}

pub const IdList = struct {
    pub const cap = 16;
    ids: [cap]u32 = undefined,
    len: u32 = 0,
};

pub const MapState = struct {
    collision_grid: Grid(IdList) = undefined,
    tile_grid: Grid(u32) = undefined,

    pub fn init(a: std.mem.Allocator) !@This() {
        return @This(){
            //TODO update this
            .collision_grid = try Grid(IdList).init(a, 10, 10),
            .tile_grid = try Grid(u32).init(a, 10, 10),
        };
    }

    pub fn render(self: *@This(), tiles: []tile.Tile, scale: f32) void {
        for (0..self.tile_grid.items.len) |x| {
            for (0..self.tile_grid.items[x].len) |y| {
                if (self.tile_grid.items[x][y]) |id| {
                    tiles[id].render(x, y, scale);
                }
            }
        }
    }
};
