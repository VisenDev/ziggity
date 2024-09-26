const std = @import("std");
const ziglua = @import("ziglua");
const anime = @import("animation.zig");
const key = @import("keybindings.zig");
const tile = @import("tiles.zig");

pub fn main() !void {
    const path = std.mem.sliceTo(std.os.argv[1], 0);
    try ziglua.define(std.heap.raw_c_allocator, path, &.{ anime.Animation, key.KeyConfig, tile.Tile });
}
