const std = @import("std");

pub fn SparseSet(comptime T: type) type {
    return struct {
        dense: std.ArrayListAlignedUnmanaged(T, null) = std.ArrayListAlignedUnmanaged(T, null){}, //dense values
        dense_ids: std.ArrayListAlignedUnmanaged(usize, null) = std.ArrayListAlignedUnmanaged(usize, null){}, //ids of values in dense array
        sparse: std.ArrayListAlignedUnmanaged(?usize, null) = std.ArrayListAlignedUnmanaged(?usize, null){}, //location in dense array of ids
        capacity: usize = 0,

        pub fn init(a: std.mem.Allocator, capacity: usize) !@This() {
            var sparse = try std.ArrayListAlignedUnmanaged(?usize, null).initCapacity(a, capacity);
            try sparse.appendNTimes(a, null, capacity);
            return @This(){
                .dense = std.ArrayListAlignedUnmanaged(T, null){},
                .dense_ids = std.ArrayListAlignedUnmanaged(usize, null){},
                .sparse = sparse,
                .capacity = capacity,
            };
        }

        pub fn increaseCapacity(self: *@This(), a: std.mem.Allocator, new_capacity: usize) !void {
            self.sparse.appendNTimes(a, null, new_capacity - self.capacity);
        }

        pub fn deinit(self: *@This(), a: std.mem.Allocator) void {
            self.dense.deinit(a);
            self.sparse.deinit(a);
            self.dense_ids.deinit(a);
        }

        pub fn set(self: *@This(), a: std.mem.Allocator, index: usize, val: T) !void {
            if (index < 0 or index > self.capacity) {
                return error.index_out_of_bounds;
            }

            if (self.get(index) != null) {
                try self.delete(index);
            }

            const index_in_dense = self.dense.items.len;

            try self.dense.append(a, val);
            try self.dense_ids.append(a, index);
            self.sparse.items[index] = index_in_dense;
        }

        pub fn insert(self: *@This(), a: std.mem.Allocator, index: usize, val: T) !void {
            if (!try self.indexEmpty(index)) {
                return error.index_not_empty;
            } else {
                try self.set(a, index, val);
            }
        }

        pub fn delete(self: *@This(), sparse_index_to_delete: usize) !void {
            if (sparse_index_to_delete < 0 or sparse_index_to_delete > self.capacity) {
                return error.index_out_of_bounds;
            } else if (try self.indexEmpty(sparse_index_to_delete)) {
                return;
            }

            //delete the index in the sparse array
            const dense_empty_location = self.sparse.items[sparse_index_to_delete].?;
            self.sparse.items[sparse_index_to_delete] = null;

            //set the now empty location to the top of the dense array
            const dense_top_value = self.dense.pop();
            const dense_top_id = self.dense_ids.pop();

            std.debug.assert(self.dense_ids.items.len == self.dense.items.len);

            if (dense_empty_location < self.dense.items.len) {
                self.dense.items[dense_empty_location] = dense_top_value;
                self.dense_ids.items[dense_empty_location] = dense_top_id;
                self.sparse.items[dense_top_id] = dense_empty_location;
            }

            //update the sparse index that used to point to the dense array top
            //self.sparse[self.dense_to_sparse[dense_empty_location].?] = dense_empty_location;
        }

        pub fn indexEmpty(self: *const @This(), index: usize) !bool {
            if (index < 0 or index > self.*.capacity) {
                return error.index_out_of_bounds;
            }
            return self.sparse.items[index] == null;
        }

        pub fn get(self: *const @This(), sparse_index: usize) ?*T {
            if (sparse_index < 0 or sparse_index > self.*.capacity) {
                //std.debug.print("ERROR: Invalid index: {}, max_index: {}\n", .{ sparse_index, self.capacity });
                return null;
            }
            const dense_index = self.sparse.items[sparse_index];
            if (dense_index == null) {
                return null;
            } else {
                return &self.dense.items[dense_index.?];
            }
        }

        pub fn slice(self: *const @This()) []T {
            return self.dense.items;
        }

        pub fn len(self: *@This()) usize {
            return self.dense.items.len;
        }
    };
}

//pub fn intersection(a: std.mem.Allocator, arr1: []usize, arr2: []usize) []usize {
//    var bitmap = std.bit_set.DynamicBitSet.initEmpty(a, 1) catch return &[0]usize{};
//    bitmap.resize(@max(arr1.len, arr2.len), false) catch return &[0]usize{};
//    defer bitmap.deinit();
//    var result = std.ArrayListAlignedUnmanaged(usize, null){};
//
//    //add element values to the bitmap
//    for (arr1) |element| {
//        bitmap.set(element);
//    }
//
//    for (arr2) |element| {
//        if (bitmap.isSet(element)) {
//            result.append(a, element) catch return &[0]usize{};
//        }
//    }
//
//    return result.items;
//}

test "sparse_set" {
    var a = std.testing.allocator;

    var set = try SparseSet(usize).init(a, 128);
    defer set.deinit(a);
    try set.insert(a, 0, 12);
    try set.insert(a, 3, 13);
    try set.insert(a, 5, 14);
    try set.insert(a, 7, 15);
    try set.delete(0);
    try set.insert(a, 1, 16);
    try set.insert(a, 0, 17);

    try set.insert(a, 100, 16);
    try set.insert(a, 19, 17);
    try set.insert(a, 127, 17);
    try set.delete(100);
    try set.delete(19);
    try set.insert(a, 9, 17);
    try set.delete(9);
    try set.delete(127);

    var set2 = try SparseSet(usize).init(a, 128);
    defer set2.deinit(a);

    try set2.insert(a, 0, 12);
    try set2.insert(a, 3, 13);
    try set2.insert(a, 5, 14);

    const string = try std.json.stringifyAlloc(a, set, .{});
    defer a.free(string);
    const parsed = try std.json.parseFromSlice(@TypeOf(set), a, string, .{});
    defer parsed.deinit();
}
