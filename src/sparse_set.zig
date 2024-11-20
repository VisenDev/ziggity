const std = @import("std");
const builtin = @import("builtin");
const assert = std.debug.assert;

pub fn SparseSet(comptime T: type) type {
    return struct {
        dense_to_sparse_map: std.ArrayListAlignedUnmanaged(usize, null) = .{},
        dense: std.ArrayListAlignedUnmanaged(T, null) = .{},
        sparse: std.ArrayListAlignedUnmanaged(?usize, null) = .{},

        pub fn init(a: std.mem.Allocator, initial_capacity: usize) !@This() {
            var sparse = try std.ArrayListAlignedUnmanaged(?usize, null).initCapacity(a, initial_capacity);
            try sparse.appendNTimes(a, null, initial_capacity);
            return .{
                .sparse = sparse,
            };
        }

        pub fn capacity(self: *const @This()) usize {
            return self.sparse.items.len;
        }

        pub fn increaseCapacity(self: *@This(), a: std.mem.Allocator, new_capacity: usize) !void {
            self.audit();
            defer self.audit();

            assert(new_capacity >= self.capacity());
            try self.sparse.appendNTimes(a, null, new_capacity - self.capacity());
        }

        pub fn deinit(self: *@This(), a: std.mem.Allocator) void {
            self.dense.deinit(a);
            self.sparse.deinit(a);
            self.dense_to_sparse_map.deinit(a);
        }

        pub fn set(self: *@This(), a: std.mem.Allocator, index: usize, val: T) !void {
            self.audit();
            defer self.audit();

            if (index < 0 or index > self.capacity()) {
                return error.index_out_of_bounds;
            }

            if (self.get(index) != null) {
                try self.delete(index);
            }

            const index_in_dense = self.dense.items.len;

            try self.dense.append(a, val);
            try self.dense_to_sparse_map.append(a, index);
            self.sparse.items[index] = index_in_dense;
        }

        pub fn setNoClobber(self: *@This(), a: std.mem.Allocator, index: usize, val: T) !void {
            self.audit();
            defer self.audit();

            assert(self.indexEmpty(index) catch false);
            try self.set(a, index, val);
        }

        pub fn delete(self: *@This(), sparse_index: usize) !void {
            self.audit();
            defer self.audit();

            if (sparse_index < 0 or sparse_index > self.capacity()) {
                return error.index_out_of_bounds;
            } else if (try self.indexEmpty(sparse_index)) {
                return;
            }

            //delete the index in the sparse array
            const dense_index = self.sparse.items[sparse_index].?;
            self.sparse.items[sparse_index] = null;

            //set the now empty location to the top of the dense array
            const dense_top_value = self.dense.pop();
            const dense_top_id = self.dense_to_sparse_map.pop();

            assert(self.dense_to_sparse_map.items.len == self.dense.items.len);

            if (dense_index < self.dense.items.len) {
                self.dense.items[dense_index] = dense_top_value;
                self.dense_to_sparse_map.items[dense_index] = dense_top_id;
                self.sparse.items[dense_top_id] = dense_index;
            }

            //update the sparse index that used to point to the dense array top
            //self.sparse[self.dense_to_sparse[dense_empty_location].?] = dense_empty_location;
        }

        fn boundsCheck(self: *const @This(), sparse_index: usize) !void {
            if (sparse_index < 0 or sparse_index > self.capacity()) {
                return error.index_out_of_bounds;
            }
        }

        pub fn indexEmpty(self: *const @This(), sparse_index: usize) !bool {
            try boundsCheck(self, sparse_index);
            return self.get(sparse_index) == null;
        }

        pub fn get(self: *const @This(), sparse_index: usize) ?*T {
            boundsCheck(self, sparse_index) catch return null;
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

        pub fn audit(self: *const @This()) void {
            if (builtin.mode != .Debug) return;
            if (true) return;

            var non_null_count: usize = 0;
            for (self.sparse.items) |maybe_index| {
                if (maybe_index) |dense_index| {
                    //std.debug.print("dense_index: {}\n", .{dense_index});
                    //assert index points to a valid dense index
                    assert(dense_index >= 0);
                    assert(dense_index < self.dense.items.len);

                    non_null_count += 1;
                }
            }
            //assert that the number of non-nil sparse values equal the dense len
            assert(non_null_count == self.dense.items.len);

            //assert every dense_to_sparse mapping is valid
            for (self.dense_to_sparse_map.items, 0..) |sparse_index, dense_index| {
                assert(sparse_index >= 0);
                assert(sparse_index < self.sparse.items.len);
                assert(self.sparse.items[sparse_index] != null);
                assert(self.sparse.items[sparse_index].? == dense_index);
            }
        }

        //pub fn len(self: *@This()) usize {
        //    return self.dense.items.len;
        //}
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
    try set.setNoClobber(a, 0, 12);
    try set.setNoClobber(a, 3, 13);
    try set.setNoClobber(a, 5, 14);
    try set.setNoClobber(a, 7, 15);
    try set.delete(0);
    try set.setNoClobber(a, 1, 16);
    try set.setNoClobber(a, 0, 17);

    try set.setNoClobber(a, 100, 16);
    try set.setNoClobber(a, 19, 17);
    try set.setNoClobber(a, 127, 17);
    try set.delete(100);
    try set.delete(19);
    try set.setNoClobber(a, 9, 17);
    try set.delete(9);
    try set.delete(127);

    var set2 = try SparseSet(usize).init(a, 128);
    defer set2.deinit(a);

    try set2.setNoClobber(a, 0, 12);
    try set2.setNoClobber(a, 3, 13);
    try set2.setNoClobber(a, 5, 14);

    const string = try std.json.stringifyAlloc(a, set, .{});
    defer a.free(string);
    const parsed = try std.json.parseFromSlice(@TypeOf(set), a, string, .{});
    defer parsed.deinit();
}
