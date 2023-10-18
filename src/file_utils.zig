const std = @import("std");
const level = @import("level.zig");
const toml = @import("toml");

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
    //const lec = try std.json.stringifyAlloc(a, l.map, .{});
    //const name = try std.json.stringifyAlloc(a, l.name, .{});
    //const id = try std.json.stringifyAlloc(a, l.player_id, .{});
    //const exits = try std.json.stringifyAlloc(a, l.exits, .{});
    //_ = exits;
    //_ = id;
    //_ = name;
    //_ = lec;
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
////========SAVE CREATION/DELETION========
////
//pub fn createSaveDir(a: std.mem.Allocator, save_id: []const u8) !void {
//    const new_save_path =
//    const new_save_levels_path = try std.fmt.allocPrint(a, "{s}/levels", .{new_save_path});
//    try std.fs.makeDirAbsolute(new_save_path);
//    try std.fs.makeDirAbsolute(new_save_levels_path);
//}

//pub const SaveState = struct {
//    name: []const u8,
//    current_level: []const u8,
//};

//pub fn readSaveState(a: std.mem.Allocator, save_id: []const u8) !SaveState {
//    const save_path = try getSavePath(a, str.findNullTerminator(save_id));
//    const path = try std.fmt.allocPrint(a, "{s}state.json", .{save_path});
//    std.debug.print("READING SAVE STATE: {s}\n", .{path});
//
//    const string = try std.fs.cwd().readFileAlloc(a, path, 2048);
//    const parsed = try std.json.parseFromSlice(SaveState, a, string, .{});
//    return parsed.value;
//}

//========CONFIG IO========
pub fn readConfig(comptime T: type, a: std.mem.Allocator, filename: []const u8) !T {
    const path = try getConfigDirPath(a);
    defer a.free(path);

    const full_path = try std.fmt.allocPrint(a, "{s}{s}", .{ path, filename });
    defer a.free(full_path);

    const string = try std.fs.cwd().readFileAlloc(a, full_path, 2048);
    //std.debug.print("\n[CONFIG STRING LOADED] {s}\n", .{string});

    const data = try std.json.parseFromSlice(T, a, string, .{});
    return data.value;
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

//pub fn readToml(comptime T: type, a: std.mem.Allocator, filename: []const u8) !T {
//    const path = try getConfigDirPath(a);
//    defer a.free(path);
//
//    const full_path = try std.fmt.allocPrint(a, "{s}{s}", .{ path, filename });
//    defer a.free(full_path);
//
//    //const string = try std.fs.cwd().readFileAlloc(a, full_path, 2048);
//
//    const config = toml.parseFile(a, full_path);
//    defer config.deinit();
//}
//
//test "toml" {
//    _ = try readToml(u32, std.testing.allocator, "test.toml");
//}

//test "config" {
//    const Key = struct {
//        char: u8,
//        shift: bool = false,
//        control: bool = false,
//    };
//
//    const KeyBindings = struct {
//        player_up: Key,
//        player_down: Key,
//        player_left: Key,
//        player_right: Key,
//    };
//
//    //_ = try readConfig(KeyBindings, std.testing.allocator, "keybindings.json");
//}
