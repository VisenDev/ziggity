const std = @import("std");
const level = @import("level.zig");

const ztoml = @import("ztoml");

pub const FileName = struct {
    pub const tiles = "tiles.toml";
    pub const keybindings = "keybindings.toml";
    pub const animations = "animations.toml";
};

//removes comments from a json file
pub fn stripComments(a: std.mem.Allocator, input: []const u8) !std.ArrayList(u8) {
    const States = enum { slash, comment_start, comment, normal };
    var state = States.normal;
    var result = std.ArrayList(u8).init(a);

    for (input) |ch| {
        state = switch (state) {
            .normal => switch (ch) {
                '/' => .slash,
                else => .normal,
            },
            .slash => switch (ch) {
                '/' => .comment_start,
                else => .normal,
            },
            .comment => switch (ch) {
                '\n' => .normal,
                else => .comment,
            },
            .comment_start => switch (ch) {
                '\n' => .normal,
                else => .comment,
            },
        };

        if (state != .comment) {
            try result.append(ch);
        }

        //remove slashes
        if (state == .comment_start) {
            _ = result.popOrNull();
            _ = result.popOrNull();
        }
    }

    return result;
}

test "stripComments" {
    const string =
        \\{
        \\  "frames": [
        \\    {
        \\    //hi I am comment
        \\    "texture": null,
        \\    "filepath": "fireball.png",
        \\    "subrect": {"x": 0, "y": 0, "width": 16, "height": 16}, //commment here
        \\    "milliseconds": 250,
        \\    "origin": {"x": 8, "y": 8}
        \\    }
        \\  ],
        \\  //Hello world
        \\  "name": "fireball",
        \\  "rotation_speed": 0
        \\}
    ;
    const removed_comments =
        \\{
        \\  "frames": [
        \\    {
        \\    
        \\    "texture": null,
        \\    "filepath": "fireball.png",
        \\    "subrect": {"x": 0, "y": 0, "width": 16, "height": 16}, 
        \\    "milliseconds": 250,
        \\    "origin": {"x": 8, "y": 8}
        \\    }
        \\  ],
        \\  
        \\  "name": "fireball",
        \\  "rotation_speed": 0
        \\}
    ;

    const commentless = try stripComments(std.testing.allocator, string);
    defer commentless.deinit();
    try std.testing.expect(std.mem.eql(u8, commentless.items, removed_comments));
}

//combines two paths
pub fn combine(a: std.mem.Allocator, str1: []const u8, str2: []const u8) ![]const u8 {
    return try std.fmt.allocPrint(a, "{s}{s}", .{ str1, str2 });
}

pub fn combineAppendSentinel(a: std.mem.Allocator, str1: []const u8, str2: []const u8) ![]const u8 {
    var str = try std.fmt.allocPrint(a, "{s}{s}#", .{ str1, str2 });
    str[str.len - 1] = 0;
    return str;
}

//========DIR PATHS========
pub fn getCWD(a: std.mem.Allocator) ![]const u8 {
    const cwd: []u8 = try std.fs.selfExeDirPathAlloc(a);
    const folder = "/game-files/";
    const result: []const u8 = try std.fmt.allocPrint(a, "{s}{s}", .{ cwd, folder });
    return result;
}

pub fn getConfigDirPath(a: std.mem.Allocator) ![]const u8 {
    const cwd: []const u8 = @as([]const u8, try getCWD(a));
    defer a.free(cwd);
    return try combine(a, cwd, "config/");
}

pub fn getSaveDirPath(a: std.mem.Allocator) ![]const u8 {
    const cwd = try getCWD(a);
    defer a.free(cwd);
    return try combine(a, cwd, "saves/");
}

pub fn getImageDirPath(a: std.mem.Allocator) ![]const u8 {
    const cwd = try getCWD(a);
    defer a.free(cwd);
    return try combine(a, cwd, "images/");
}

//=========FILE PATHS============
pub fn getLevelPath(a: std.mem.Allocator, save_id: []const u8, level_id: []const u8) ![]const u8 {
    const save_path = try getSavePath(a, save_id);
    defer a.free(save_path);
    return try std.fmt.allocPrint(a, "{s}levels/{s}.json", .{ save_path, level_id });
}

pub fn getSavePath(a: std.mem.Allocator, save_id: []const u8) ![]const u8 {
    const save_dir = try getSaveDirPath(a);
    defer a.free(save_dir);
    return try std.fmt.allocPrint(a, "{s}{s}/", .{ save_dir, save_id });
}

//========LEVEL IO========
pub fn readLevel(a: std.mem.Allocator, save_id: []const u8, level_id: []const u8) !std.json.Parsed(level.Level) {
    //
    //    const decoder = std.base64.Base64Decoder.init(std.base64.standard_alphabet_chars, null);
    //    var string = try a.alloc(u8, try decoder.calcSizeForSlice(bytes));
    //    _ = try decoder.decode(string, bytes);
    //
    //    const result = @intFromPtr(string.ptr);
    //    return @as(*level.Level, @ptrFromInt(result)).*;

    const path = try getLevelPath(a, save_id, level_id);
    const max_bytes = 10000000; //maximum bytes in a level save file
    const string = try std.fs.cwd().readFileAlloc(a, path, max_bytes);

    if (!try std.json.validate(a, string)) {
        return error.invalid_json;
    }

    return try std.json.parseFromSlice(level.Level, a, string, .{ .allocate = .alloc_always });
}

//pub fn writeLevel(a: std.mem.Allocator, l: level.Level, save_id: []const u8, level_id: []const u8) !void {
//    const bytes = std.mem.asBytes(&l);
//    const encoder = std.base64.Base64Encoder.init(std.base64.standard_alphabet_chars, null);
//
//    var string = try a.alloc(u8, encoder.calcSize(bytes.len));
//    defer a.free(string);
//    _ = encoder.encode(string, bytes);
//
//    const path = try getLevelPath(a, save_id, level_id);
//    var file = try std.fs.createFileAbsolute(path, .{});
//
//    try file.writeAll(string);
//}

pub fn writeLevel(a: std.mem.Allocator, l: level.Level, save_id: []const u8, level_id: []const u8) !void {
    //const ec = try std.json.stringifyAlloc(a, l.ecs, .{});
    //_ = ec;
    ////const lec = try std.json.stringifyAlloc(a, l.map, .{});
    //const ggg = try std.json.stringifyAlloc(a, l.map.tile_grid, .{});
    //_ = ggg;
    //const gg = try std.json.stringifyAlloc(a, l.map.animation_grid, .{});
    //_ = gg;
    //const g = try std.json.stringifyAlloc(a, l.map.collision_grid, .{});
    //_ = g;

    //const name = try std.json.stringifyAlloc(a, l.name, .{});
    //_ = name;
    //const id = try std.json.stringifyAlloc(a, l.player_id, .{});
    //_ = id;
    //const exits = try std.json.stringifyAlloc(a, l.exits, .{});
    //_ = exits;
    //std.debug.print("map: {any}\n", .{lec});
    l.ecs.prepForStringify(a);
    const string = try std.json.stringifyAlloc(a, l, .{});
    const path = try getLevelPath(a, save_id, level_id);
    var file = try std.fs.createFileAbsolute(path, .{});
    try file.writeAll(string);
}
//
//test "json" {
//    var my_arena = std.heap.ArenaAllocator.init(std.testing.allocator);
//    defer my_arena.deinit();
//    const a = my_arena.allocator();
//
//    const first_level_id = "level_1";
//    const biomes = [_]level.Level.Record{.{ .name = "cave", .weight = 10 }};
//    const lvl = try level.Level.generate(a, .{ .name = first_level_id, .biomes = &biomes });
//    const string = try std.json.stringifyAlloc(a, lvl, .{});
//
//    std.debug.print("\nsize of string: {}\n", .{string.len});
//    if (!try std.json.validate(a, string)) {
//        return error.invalid_json;
//    }
//    const parsed = try std.json.parseFromSlice(level.Level, a, string, .{});
//    const parsed_2 = try std.json.parseFromSlice(level.Level, a, string, .{});
//    _ = parsed;
//    _ = parsed_2;
//    //std.debug.print("{}\n", .{parsed.value});
//}
//

//========CONFIG IO========
pub fn toSlice(str: [*c]u8) []u8 {
    const len = std.mem.indexOfSentinel(u8, 0, str);
    return str[0..len];
}

pub fn readConfig(comptime T: type, a: std.mem.Allocator, filename: []const u8) !std.json.Parsed(T) {
    const path = try getConfigDirPath(a);
    defer a.free(path);

    const full_path = try std.fmt.allocPrint(a, "{s}{s}", .{ path, filename });
    defer a.free(full_path);

    var string = try std.fs.cwd().readFileAlloc(a, full_path, 2048);
    var sentinel_string = try a.dupeZ(u8, string);
    defer a.free(string);

    std.debug.print("trying to parse {s}\n", .{filename});
    std.debug.print("\n{s}\n\n", .{string});

    if (std.mem.eql(u8, "toml", filename[(filename.len - 4)..])) {
        return try ztoml.parseToml(T, a, sentinel_string);
    }

    //const comment_free = try stripComments(a, string);
    //defer comment_free.deinit();

    return try std.json.parseFromSlice(T, a, string, .{ .allocate = .alloc_always });
}

//============MANIFEST PARSING============
pub const Manifest = struct {
    pub const filename = "manifest.json";
    active_level_id: []const u8,
};

pub fn readManifest(a: std.mem.Allocator, save_id: []const u8) !std.json.Parsed(Manifest) {
    const save_path = try getSavePath(a, save_id);
    defer a.free(save_path);
    const path = try combine(a, save_path, Manifest.filename);
    defer a.free(path);
    const string = try std.fs.cwd().readFileAlloc(a, path, 2048);
    defer a.free(string);

    std.debug.print("Manifest contents = {s}\n\n", .{string});

    const parsed = try std.json.parseFromSlice(Manifest, a, string, .{ .allocate = .alloc_always });
    return parsed;
}
