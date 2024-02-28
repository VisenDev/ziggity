const std = @import("std");
const Lua = @import("ziglua").Lua;
const file = @import("file_utils.zig");
const ray = @cImport({
    @cInclude("raylib.h");
});

//================KeyBindings======================

pub const KeyMode = enum { insert, normal };

pub const Key = struct {
    name: []const u8,
    char: u16,
    shift: bool = false,
    control: bool = false,
    mode: KeyMode = .normal,
};

fn eql(a: []const u8, b: []const u8) bool {
    return std.mem.eql(u8, a, b);
}

fn match(a: []const u8, matches: []const []const u8) bool {
    for (matches) |m| {
        if (eql(a, m)) {
            return true;
        }
    }
    return false;
}

fn getArrowMatches(a: std.mem.Allocator, direction: []const u8) ![]const []const u8 {
    const patterns = comptime [_][]const u8{ "{s}", "{s}_arrow", "arrow_{s}", "key {s}", "arrow {s}" };
    var result = try a.alloc([]const u8, patterns.len);
    inline for (patterns, 0..) |pattern, i| {
        result[i] = try std.fmt.allocPrint(a, pattern, .{direction});
    }
    return result;
}

pub const KeyBindings = struct {
    keys: std.StringHashMap(Key),
    mode: KeyMode = .normal,

    pub fn init(a: std.mem.Allocator, lua: *Lua) !@This() {
        var result = KeyBindings{
            .keys = std.StringHashMap(Key).init(a),
        };

        const ConfigType = struct {
            name: []const u8,
            key: []const u8,
            shift: bool = false,
            control: bool = false,
            mode: KeyMode = .normal,
        };
        const config = try file.readConfig([]ConfigType, lua, .keybindings);
        defer config.deinit();

        var arena_value = std.heap.ArenaAllocator.init(a);
        const arena = arena_value.allocator();
        defer arena_value.deinit();

        for (config.value) |key_config| {
            var resulting_key = Key{
                .name = key_config.name,
                .char = key_config.key[0],
                .mode = key_config.mode,
                .shift = key_config.shift,
                .control = key_config.control,
            };
            if (key_config.key.len > 1) {
                if (match(key_config.key, try getArrowMatches(arena, "up"))) {
                    resulting_key.char = ray.KEY_UP;
                } else if (match(key_config.key, try getArrowMatches(arena, "down"))) {
                    resulting_key.char = ray.KEY_DOWN;
                } else if (match(key_config.key, try getArrowMatches(arena, "left"))) {
                    resulting_key.char = ray.KEY_LEFT;
                } else if (match(key_config.key, try getArrowMatches(arena, "right"))) {
                    resulting_key.char = ray.KEY_RIGHT;
                } else if (match(key_config.key, &[_][]const u8{ "enter", "return", "<cr>" })) {
                    resulting_key.char = ray.KEY_ENTER;
                }
            }

            try result.insert(resulting_key);
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

            if (!ray.IsKeyDown(key.char)) {
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

        //std.debug.print("attempted to use keybinding \"{s}\" that does not exist\n", .{key_name});
        return false;
    }

    pub fn isPressed(self: *const @This(), key_name: []const u8) bool {
        if (self.keys.get(key_name)) |key| {
            if (key.mode != self.mode) {
                return false;
            }

            if (!ray.IsKeyPressed(key.char)) {
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

        //std.debug.print("attempted to use keybinding \"{s}\" that does not exist\n", .{key_name});
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
