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
    player_up: Key,
    player_down: Key,
    player_left: Key,
    player_right: Key,
    zoom_in: Key,
    zoom_out: Key,

    pub fn init(a: std.mem.Allocator) !@This() {
        std.debug.print("Attempting to load key_bindings\n", .{});
        const json_config = try file.readConfig(@This(), a, "keybindings.json");
        defer json_config.deinit();

        return json_config.value;
    }

    pub fn deinit(self: *const @This(), a: std.mem.Allocator) void {
        _ = a;
        _ = self;
        //a.destroy(self);
    }
};
