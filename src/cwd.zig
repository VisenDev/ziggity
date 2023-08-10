const std = @import("std");
const whereami = @cImport({
    @cInclude("whereami.h");
});

pub fn resolveCWD() !void {
    var buffer: [1024:0]u8 = undefined;
    const len = whereami.wai_getExecutablePath(&buffer, @as(c_uint, buffer.len), 0);
    var last_slash_index: usize = 0;
    for (0..@intCast(len)) |index| {
        if (buffer[index] == '/') {
            last_slash_index = index;
        }
    }
    const slice = buffer[0..last_slash_index];
    try std.os.chdir(slice);
}
