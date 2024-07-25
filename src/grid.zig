const Allocator = std.mem.Allocator;
const std = @import("std");

pub fn Grid(comptime T: type) type {
    return struct {
        items: []T,
        width: usize,
        height: usize,

        pub fn init(a: std.mem.Allocator, width: usize, height: usize, value: T) !@This() {
            const grid = @This(){
                .items = try a.alloc(T, width * height),
                .width = width,
                .height = height,
            };
            @memset(grid.items, value);
            return grid;
        }

        pub fn deinit(self: *@This(), a: std.mem.Allocator) void {
            a.free(self.items);
        }

        pub fn at(self: *const @This(), x: usize, y: usize) ?*T {
            if (x < 0 or x >= self.width or y < 0 or y >= self.height) {
                return null;
            }

            return &self.items[x * self.width + y];
        }

        ///asserts that the index exists
        pub inline fn get(self: *const @This(), x: usize, y: usize) T {
            return self.at(x, y).?.*;
        }

        ///for debugging
        pub fn printContents(self: *const @This()) void {
            std.debug.print("\n", .{});
            std.debug.print("\n", .{});
            for (0..self.height) |y| {
                for (0..self.width) |x| {
                    std.debug.print("{any}, ", .{self.get(x, y)});
                }
                std.debug.print("\n", .{});
            }
        }

        pub fn countMatchingNearby(self: *const @This(), x: usize, y: usize, match: T) usize {
            var count: usize = 0;
            const nearby = self.findNearbyCells(x, y);
            for (nearby, 0..) |cell, i| {
                //skip index five so the cell doesn't count itself
                if (i != 5 and cell != null and cell.?.* == match) {
                    count += 1;
                }
            }
            return count;
        }

        pub fn findNearbyCells(self: *const @This(), x: usize, y: usize) [9]?*T {
            var i: usize = 0;
            var nearbyCells: [9]?*T = undefined;

            for (0..3) |offset_y| {
                for (0..3) |offset_x| {
                    const final_x: usize = @intCast(@max(@as(isize, @intCast(x + offset_x)) - 1, 0));
                    const final_y: usize = @intCast(@max(@as(isize, @intCast(y + offset_y)) - 1, 0));
                    nearbyCells[i] = self.at(final_x, final_y);
                    i += 1;
                }
            }

            return nearbyCells;
        }
    };
}

//pub fn Grid(comptime T: type) type {
//    return struct {
//        items: [][]T = &[_][]T{},
//        neighbor_list: std.ArrayListUnmanaged(T) = .{},
//        default_value: T,
//
//        pub fn init(a: Allocator, width: usize, height: usize, default_value: T) !@This() {
//            const base = try a.alloc([]T, width);
//            for (base) |*item| {
//                item.* = try a.alloc(T, height);
//                @memset(item.*, default_value);
//            }
//            return @This(){
//                .items = base,
//                .neighbor_list = try std.ArrayListUnmanaged(T).initCapacity(a, 9),
//                .default_value = default_value,
//            };
//        }
//
//        pub inline fn getWidth(self: *const @This()) usize {
//            return self.items.len;
//        }
//
//        pub inline fn getHeight(self: *const @This()) usize {
//            if (self.getWidth() == 0) return 0;
//            return self.items[0].len;
//        }
//
//        pub inline fn get(self: *const @This(), x: usize, y: usize) ?*T {
//            if (!self.isValidIndex(x, y)) return null;
//            return &self.items[x][y];
//        }
//
//        pub inline fn set(self: *@This(), a: std.mem.Allocator, x: usize, y: usize, value: T) !void {
//            if (x < 0 or y < 0) @panic("negative index given");
//            while (!self.isValidIndex(x, y)) {
//                //std.debug.print("x: {}, y: {} desired\n", .{ x, y });
//                //std.debug.print("resizing: width{}, height{}\n", .{ self.getWidth(), self.getHeight() });
//                try self.expand(a, 2 * self.getWidth() + 1, 2 * self.getHeight() + 1);
//            }
//
//            self.items[x][y] = value;
//        }
//
//        pub inline fn getOrSet(self: *@This(), a: std.mem.Allocator, x: usize, y: usize, value: T) !*T {
//            if (self.get(x, y)) |val| {
//                return val;
//            } else {
//                try self.set(a, x, y, value);
//                return self.get(x, y).?;
//            }
//        }
//
//        pub fn expand(self: *@This(), a: std.mem.Allocator, new_width: usize, new_height: usize) !void {
//            const old_width = self.items.len;
//
//            self.items = try a.realloc(self.items, new_width);
//
//            //alloc new columns
//            for (self.items[old_width..new_width]) |*column| {
//                column.* = try a.alloc(T, new_height);
//                @memset(column.*, self.default_value);
//            }
//
//            //reallocate old columns
//            for (self.items[0..old_width]) |*column| {
//                column.* = try a.realloc(column.*, new_height);
//            }
//        }
//
//        pub fn clear(self: *@This(), default_value: T) void {
//            for (self.items) |*item| {
//                @memset(item.*, default_value);
//            }
//        }
//
//        pub fn deinit(self: *@This(), a: Allocator) void {
//            for (self.items) |item| {
//                a.free(item);
//            }
//            a.free(self.items);
//            self.neighbor_list.deinit(a);
//        }
//
//        pub fn isValidIndex(self: *const @This(), x: anytype, y: anytype) bool {
//            return x >= 0 and x < self.items.len and y >= 0 and y < self.items[x].len;
//        }
//
//        ///Must be called before json.stringify
//        pub fn prepForStringify(self: *@This()) void {
//            self.neighbor_list.capacity = 0;
//        }
//
//        ///finds neighbors to any given cell
//        pub fn findNeighbors(self: *@This(), a: std.mem.Allocator, search_x: usize, search_y: usize) []T {
//            var len: usize = 0;
//
//            if (self.neighbor_list.items.len < 9) {
//                self.neighbor_list.appendNTimes(a, self.default_value, 9) catch return self.neighbor_list.items;
//            }
//
//            for (0..3) |x_offset| {
//                for (0..3) |y_offset| {
//                    //prevent integer overflow
//                    if (search_x + x_offset == 0 or search_y + y_offset == 0) continue;
//
//                    const x = search_x + x_offset - 1;
//                    const y = search_y + y_offset - 1;
//
//                    if (!self.isValidIndex(x, y)) {
//                        continue;
//                    }
//
//                    self.neighbor_list.items[len] = self.items[x][y];
//                    len += 1;
//                }
//            }
//
//            return self.neighbor_list.items[0..len];
//        }
//
//        pub const Neighborhood = struct {
//            const Row = struct { left: ?*T, middle: ?*T, right: ?*T };
//            top: Row = .{},
//            center: Row = .{},
//            bottom: Row = .{},
//        };
//
//        pub fn getNeighborhood(self: *const @This(), raw_x: usize, raw_y: usize) Neighborhood {
//            var result: Neighborhood = undefined;
//            const x: i128 = @intCast(raw_x);
//            const y: i128 = @intCast(raw_y);
//            result.top.left = self.get(@intCast(@max(x - 1, 0)), @intCast(@max(y - 1, 0)));
//            result.top.middle = self.get(@intCast(@max(x, 0)), @intCast(@max(y - 1, 0)));
//            result.top.right = self.get(@intCast(@max(x + 1, 0)), @intCast(@max(y - 1, 0)));
//
//            result.center.left = self.get(@intCast(@max(x - 1, 0)), @intCast(@max(y, 0)));
//            result.center.middle = self.get(@intCast(@max(x, 0)), @intCast(@max(y, 0)));
//            result.center.right = self.get(@intCast(@max(x + 1, 0)), @intCast(@max(y, 0)));
//
//            result.bottom.left = self.get(@intCast(@max(x - 1, 0)), @intCast(@max(y + 1, 0)));
//            result.bottom.middle = self.get(@intCast(@max(x, 0)), @intCast(@max(y + 1, 0)));
//            result.bottom.right = self.get(@intCast(@max(x + 1, 0)), @intCast(@max(y + 1, 0)));
//
//            return result;
//        }
//
//        pub const Iterator = struct {
//            items: [][]?T,
//            x: usize = 0,
//            y: usize = 0,
//
//            pub fn next(self: *Iterator) ?T {
//                if (self.x >= self.items.len) {
//                    return null;
//                }
//
//                const result = self.items[self.x][self.y];
//
//                self.y += 1;
//                if (self.y >= self.items[self.x].len) {
//                    self.y = 0;
//                    self.x += 1;
//                }
//
//                return result;
//            }
//        };
//
//        pub fn iterator(self: *const @This()) Iterator {
//            return .{ .items = self.items };
//        }
//    };
//}
//
test "grid.zig" {
    const a = std.testing.allocator;
    var grid = try Grid(f32).init(a, 32, 32, 0);
    defer grid.deinit(a);
    try std.testing.expect(grid.width == 32);
    try std.testing.expect(grid.height == 32);

    //try grid.expand(a, 56, 56);
    //try std.testing.expect(grid.getWidth() == 56);
    //try std.testing.expect(grid.getHeight() == 56);

    //try grid.set(a, 1, 1, 123.0);
    //try std.testing.expect(grid.get(1, 1).?.* == 123.0);

    //const gotten = try grid.getOrSet(a, 123, 123, 45.0);
    //try std.testing.expect(gotten.* == 45.0);
}
