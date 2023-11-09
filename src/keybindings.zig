const std = @import("std");
const file = @import("file_utils.zig");
const ray = @cImport({
    @cInclude("raylib.h");
});

//================KeyBindings======================

pub const KeyMode = enum { insert, normal };

pub const Key = struct {
    name: []const u8,
    char: [1]u8,
    shift: bool = false,
    control: bool = false,
    mode: KeyMode = .normal,
};

pub const KeyBindings = struct {
    keys: std.StringHashMap(Key),
    mode: KeyMode = .normal,

    pub fn init(a: std.mem.Allocator) !@This() {
        var result = KeyBindings{
            .keys = std.StringHashMap(Key).init(a),
        };

        const toml_type = struct {
            keys: []Key,
        };
        const json_config = try file.readConfig(toml_type, a, file.FileName.keybindings);
        defer json_config.deinit();

        for (json_config.value.keys) |key| {
            try result.insert(key);
        }

        return result;
    }

    pub fn deinit(self: *@This()) void {
        self.keys.deinit();
    }

    pub fn insert(self: *@This(), key: Key) !void {
        try self.keys.put(key.name, key);
    }

    pub fn isDown(self: *const @This(), key_name: []const u8) bool {
        if (self.keys.get(key_name)) |key| {
            if (key.mode != self.mode) {
                return false;
            }

            std.debug.print("key.char, {}\n", .{key.char[0]});
            if (!ray.IsKeyDown(key.char[0])) {
                return false;
            }

            if (key.shift and !ray.IsKeyPressed(ray.KEY_LEFT_SHIFT) and !ray.IsKeyPressed(ray.KEY_RIGHT_SHIFT)) {
                return false;
            }

            if (key.control and !ray.IsKeyPressed(ray.KEY_LEFT_CONTROL) and !ray.IsKeyPressed(ray.KEY_RIGHT_CONTROL)) {
                return false;
            }

            return true;
        }

        std.debug.print("attempted to use keybinding \"{s}\" that does not exist\n", .{key_name});
        return false;
    }

    pub fn isPressed(self: *const @This(), key_name: []const u8) bool {
        if (self.keys.get(key_name)) |key| {
            if (key.mode != self.mode) {
                return false;
            }

            if (!ray.IsKeyPressed(key.char[0])) {
                return false;
            }

            if (key.shift and !ray.IsKeyDown(ray.KEY_LEFT_SHIFT) and !ray.IsKeyDown(ray.KEY_RIGHT_SHIFT)) {
                return false;
            }

            if (key.control and !ray.IsKeyDown(ray.KEY_LEFT_CONTROL) and !ray.IsKeyDown(ray.KEY_RIGHT_CONTROL)) {
                return false;
            }

            return true;
        }

        std.debug.print("attempted to use keybinding \"{s}\" that does not exist\n", .{key_name});
        return false;
    }
};

//pub const KeyBindings = struct {
//    player_up: Key = .{ .char = 'W' },
//    player_down: Key = .{ .char = 'S' },
//    player_left: Key = .{ .char = 'A' },
//    player_right: Key = .{ .char = 'D' },
//    zoom_in: Key = .{ .char = '=' },
//    zoom_out: Key = .{ .char = '-' },
//    debug_mode: Key = .{ .char = '/' },
//    console: Key = .{ .char = 'T' },
//
//    pub fn init(a: std.mem.Allocator) !@This() {
//        const json_config = file.readConfig(@This(), a, file.FileName.keybindings) catch return @This(){};
//        defer json_config.deinit();
//
//        return json_config.value;
//    }
//
//    pub fn deinit(self: *const @This(), a: std.mem.Allocator) void {
//        _ = a;
//        _ = self;
//    }
//
//    pub fn update(self: *@This(), player_is_typing: bool) void {
//        _ = player_is_typing;
//        _ = self;
//    }
//};
