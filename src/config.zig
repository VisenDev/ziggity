const std = @import("std");
const file = @import("file_utils.zig");
const ray = @cImport({
    @cInclude("raylib.h");
    @cInclude("raygui.h");
    @cInclude("style_dark.h");
});

pub const Key = struct {
    char: u8,
    shift: bool = false,
    control: bool = false,

    pub fn pressed(self: @This()) bool {
        if (!ray.IsKeyPressed(self.char)) {
            return false;
        }

        if (self.shift and !ray.IsKeyPressed(ray.KEY_LEFT_SHIFT) and !ray.IsKeyPressed(ray.KEY_RIGHT_SHIFT)) {
            return false;
        }

        if (self.control and !ray.IsKeyPressed(ray.KEY_LEFT_CONTROL) and !ray.IsKeyPressed(ray.KEY_RIGHT_CONTROL)) {
            return false;
        }

        return true;
    }
};

pub const KeyBindings = struct {
    player_up: Key,
    player_down: Key,
    player_left: Key,
    player_right: Key,

    const Self = @This();

    pub fn init(a: std.mem.Allocator) !Self {
        const res = try file.readConfig(Self, a, "keybindings.json");
        return res;
    }
};
