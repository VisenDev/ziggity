const std = @import("std");
const file = @import("file_utils.zig");
const ray = @cImport({
    @cInclude("raylib.h");
});

//================KeyBindings======================

var deactivated = false;

pub const Key = struct {
    char: u8,
    shift: bool = false,
    control: bool = false,

    pub fn pressed(self: @This()) bool {
        if (deactivated) return false;

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

    pub fn down(self: @This()) bool {
        if (deactivated) return false;

        if (!ray.IsKeyDown(self.char)) {
            return false;
        }

        if (self.shift and !ray.IsKeyDown(ray.KEY_LEFT_SHIFT) and !ray.IsKeyDown(ray.KEY_RIGHT_SHIFT)) {
            return false;
        }

        if (self.control and !ray.IsKeyDown(ray.KEY_LEFT_CONTROL) and !ray.IsKeyDown(ray.KEY_RIGHT_CONTROL)) {
            return false;
        }

        return true;
    }
};

pub const KeyBindings = struct {
    player_up: Key = .{ .char = 'W' },
    player_down: Key = .{ .char = 'S' },
    player_left: Key = .{ .char = 'A' },
    player_right: Key = .{ .char = 'D' },
    zoom_in: Key = .{ .char = '=' },
    zoom_out: Key = .{ .char = '-' },
    debug_mode: Key = .{ .char = '/' },
    console: Key = .{ .char = 'T' },

    pub fn init(a: std.mem.Allocator) !@This() {
        const json_config = file.readConfig(@This(), a, file.FileName.keybindings) catch return @This(){};
        defer json_config.deinit();

        return json_config.value;
    }

    pub fn deinit(self: *const @This(), a: std.mem.Allocator) void {
        _ = a;
        _ = self;
    }

    pub fn update(self: *@This(), player_is_typing: bool) void {
        _ = self;
        deactivated = player_is_typing;
    }
};
