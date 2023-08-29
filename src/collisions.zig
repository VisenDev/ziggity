const std = @import("std");

pub fn Grid(comptime T: type, comptime width: u32, comptime height: u32, comptime max_values_in_cell: u32) type {
    const Cell = struct {
        num_values: u32 = 0,
        values: [max_values_in_cell]T = undefined,
    };

    return struct {
        const max_num_neightbors = max_values_in_cell * 9;
        const max_num_modified_cells = 1024;

        contents: [width][height]Cell = undefined,
        neighbor_list: [max_num_neightbors]T = undefined,

        num_modified_cells: u32 = 0,
        modified_cells: [max_num_modified_cells]struct { x: u32, y: u32 },

        pub fn insert(self: *@This(), value: T, x: u32, y: u32) !void {
            const num = self.contents[x][y].num_values;
            if (num < max_values_in_cell) {
                self.contents[x][y].values[num] = value;
                self.contents[x][y].num_values += 1;

                //track modified cells
                if (self.num_modified_cells < max_num_modified_cells) {
                    self.modified_cells[self.num_modified_cells] = .{ .x = x, .y = y };
                }

                self.num_modified_cells += 1;
            } else {
                std.debug.print("num = {}, cap = {}\n", .{ num, max_values_in_cell });
                return error.capacity_full;
            }
        }

        pub fn find_neighbors(self: *@This(), x: u32, y: u32) []T {
            var num_neighbors: u32 = 0;
            for (0..3) |x_offset| {
                for (0..3) |y_offset| {
                    const x_index = x + x_offset - 1;
                    const y_index = y + y_offset - 1;

                    if (x_index > 0 and x_index < width and y_index > 0 and y_index < height) {
                        for (0..self.contents[x_index][y_index].num_values) |i| {
                            self.neighbor_list[num_neighbors] = self.contents[x_index][y_index].values[i];
                            num_neighbors += 1;
                        }
                    }
                }
            }
            return self.neighbor_list[0..num_neighbors];
        }

        pub fn clear(self: *@This()) void {
            if (self.num_modified_cells < max_num_modified_cells) {
                for (0..self.num_modified_cells) |i| {
                    const val = self.modified_cells[i];
                    self.contents[val.x][val.y] = Cell{ .num_values = 0 };
                }
            } else {
                @memset(&self.contents, [_]Cell{Cell{ .num_values = 0 }} ** height);
            }

            self.num_modified_cells = 0;
        }

        pub fn init(a: std.mem.Allocator) !*@This() {
            var result = try a.create(@This());
            result.clear();
            return result;
        }
    };
}

test "collision" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var map = try Grid(usize, 2000, 2000, 16).init(gpa.allocator());

    for (0..1000) |_| {
        try map.insert(1000, 2, 1);
        try map.insert(1000, 1, 8);
        try map.insert(1000, 4, 2);
        try map.insert(1000, 2, 2);
        try map.insert(1000, 5, 5);
        try map.insert(1000, 5, 5);
        try map.insert(1200, 5, 5);
        try map.insert(1300, 5, 5);
        try map.insert(1400, 5, 5);
        try map.insert(1000, 5, 5);
        try map.insert(4444, 4, 4);
        try map.insert(4444, 6, 6);
        try map.insert(1000, 2, 2);
        _ = map.find_neighbors(5, 5);
        map.clear();
    }

    //@import("std").debug.print("{any}\n", .{map.find_neighbors(5, 5)});
}
