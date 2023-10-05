const std = @import("std");

pub fn SparseSet(comptime T: type, comptime max_capacity: usize) type {
    const Entry = struct {
        val: T,
        id: usize,
    };

    return struct {
        dense: std.ArrayListAlignedUnmanaged(Entry, null) = std.ArrayListAlignedUnmanaged(Entry, null){},
        sparse: [max_capacity]?usize = [1]?usize{null} ** max_capacity,
        capacity: usize = max_capacity,

        pub fn init(a: std.mem.Allocator) !@This() {
            _ = a;
            return @This(){
                .dense = std.ArrayListAlignedUnmanaged(Entry, null){},
                .sparse = [_]?usize{null} ** max_capacity,
                .capacity = max_capacity,
            };
        }

        pub fn deinit(self: *@This(), a: std.mem.Allocator) void {
            self.*.dense.deinit(a);
        }

        pub fn insert(self: *@This(), a: std.mem.Allocator, index: usize, val: T) !void {
            if (index < 0 or index > self.*.capacity) {
                return error.index_out_of_bounds;
            }
            if (!try self.indexEmpty(index)) {
                return error.index_not_empty;
            }
            const index_in_dense = self.dense.items.len;

            std.debug.print("[SPARSE INSERT] index: {}\n", .{index});
            //TODO delete this line
            try self.dense.ensureTotalCapacity(a, self.dense.items.len + 2);
            try self.dense.append(a, .{
                .val = val,
                .id = index,
            });
            self.sparse[index] = index_in_dense;
        }

        pub fn delete(self: *@This(), sparse_index_to_delete: usize) !void {
            if (sparse_index_to_delete < 0 or sparse_index_to_delete > self.capacity) {
                return error.index_out_of_bounds;
            } else if (try self.indexEmpty(sparse_index_to_delete)) {
                return;
            }

            //delete the index in the sparse array
            const dense_empty_location = self.sparse[sparse_index_to_delete].?;
            self.sparse[sparse_index_to_delete] = null;

            //set the now empty location to the top of the dense array
            const dense_top_value = self.dense.pop();
            self.dense.items[dense_empty_location] = dense_top_value;

            //update the sparse index that used to point to the dense array top
            self.sparse[self.dense_to_sparse[dense_empty_location].?] = dense_empty_location;
        }

        pub fn indexEmpty(self: *const @This(), index: usize) !bool {
            if (index < 0 or index > self.*.capacity) {
                return error.index_out_of_bounds;
            }
            return self.sparse[index] == null;
        }

        pub fn get(self: *const @This(), sparse_index: usize) ?*T {
            if (sparse_index < 0 or sparse_index > self.*.capacity) {
                std.debug.print("ERROR: Invalid index: {}, max_index: {}\n", .{ sparse_index, self.capacity });
                return null;
            }
            const dense_index = self.sparse[sparse_index];
            if (dense_index == null) {
                return null;
            } else {
                return &self.dense.items[dense_index.?].val;
            }
        }

        pub fn slice(self: *const @This()) []Entry {
            return self.dense.items;
        }

        pub fn len(self: *@This()) usize {
            return self.dense.items.len;
        }
    };
}

test "sparse_set" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var a = gpa.allocator();

    var set = try SparseSet(usize, 128).init(a);
    try set.insert(a, 0, 12);
    try set.insert(a, 3, 13);
    try set.insert(a, 5, 14);
    try set.insert(a, 7, 15);

    const string = try std.json.stringifyAlloc(a, set, .{});
    std.debug.print("{s}\n\n\n", .{string});
    const parsed = try std.json.parseFromSlice(@TypeOf(set), a, string, .{});
    std.debug.print("{}\n\n\n", .{parsed.value});
}
