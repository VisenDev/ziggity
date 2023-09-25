//copies a string and null terminates it
pub fn strcpy(dest: []u8, src: []const u8) !void {
    if (dest.len < src.len + 1) {
        return error.destination_buffer_too_small;
    }
    var i: usize = 0;
    for (src) |ch| {
        dest[i] = ch;
        i += 1;
    }
    dest[i] = 0;
}

pub fn findNullTerminator(str: []const u8) []const u8 {
    for (str, 0..) |ch, i| {
        if (ch == 0) {
            return str[0..i];
        }
    }

    return str;
}
