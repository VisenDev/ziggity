const std = @import("std");

pub fn SparseSet(comptime T: type, comptime max_capacity: usize) type {
    return struct {
        dense: std.ArrayList(T),
        dense_to_sparse: [max_capacity]?usize,
        sparse: [max_capacity]?usize,
        capacity: usize,

        pub fn init(a: std.mem.Allocator) @This() {
            return @This(){
                .dense = std.ArrayList(T).init(a),
                .dense_to_sparse = [_]?usize{null} ** max_capacity,
                .sparse = [_]?usize{null} ** max_capacity,
                .capacity = max_capacity,
            };
        }

        pub fn deinit(self: *@This()) void {
            self.*.dense.deinit();
        }

        pub fn insert(self: *@This(), index: usize, val: T) !void {
            if (index < 0 or index > self.*.capacity) {
                return error.index_out_of_bounds;
            }
            if (!try self.indexEmpty(index)) {
                return error.index_not_empty;
            }
            const index_in_dense = self.dense.items.len;
            try self.dense.append(val);
            self.sparse[index] = index_in_dense;
            self.dense_to_sparse[index_in_dense] = index;
        }

        pub fn delete(self: *@This(), sparse_index_to_delete: usize) !void {
            if (sparse_index_to_delete < 0 or sparse_index_to_delete > self.capacity) {
                return error.index_out_of_bounds;
            }
            if (try self.indexEmpty(sparse_index_to_delete)) {
                return;
            }

            //delete the index in the sparse array
            const dense_empty_location = self.sparse[sparse_index_to_delete].?;
            self.sparse[sparse_index_to_delete] = null;

            //set the now empty location to the top of the dense array
            const dense_top_value = self.dense.pop();

            if (sparse_index_to_delete != self.dense_to_sparse[dense_empty_location]) {
                self.dense.items[dense_empty_location] = dense_top_value;
                self.dense_to_sparse[dense_empty_location] = null;

                //update the sparse index that used to point to the dense array top
                self.sparse[self.dense_to_sparse[dense_empty_location].?] = dense_empty_location;
            }
        }

        pub fn indexEmpty(self: *@This(), index: usize) !bool {
            if (index < 0 or index > self.*.capacity) {
                return error.index_out_of_bounds;
            }
            return self.sparse[index] == null;
        }

        pub fn iterate(self: *@This()) []T {
            return self.dense.items;
        }
    };
}
