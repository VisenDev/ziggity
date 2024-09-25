const std = @import("std");
const ziglua = @import("ziglua");
const anime = @import("animation.zig");
const key = @import("keybindings.zig");

pub fn main() !void {
    //var buffer = [_]u8{0} ** 100_000;
    //var alloc = std.heap.FixedBufferAllocator.init(&buffer);

    const to_define: []const ziglua.DefineEntry = &.{
        .{ .name = "Animation", .type = anime.Animation },
        .{ .name = "Options", .type = anime.RenderOptions },
        .{ .name = "Key", .type = key.Key },
    };
    const path = std.mem.sliceTo(std.os.argv[1], 0);
    try ziglua.define(std.heap.raw_c_allocator, path, to_define);
}
