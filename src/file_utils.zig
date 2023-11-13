const std = @import("std");
const level = @import("level.zig");

const ztoml = @import("ztoml");
const zigtoml = @import("toml");

pub const FileName = struct {
    pub const tiles = "tiles.toml";
    pub const keybindings = "keybindings.toml";
    pub const animations = "animations.toml";
};

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
    const path = try getLevelPath(a, save_id, level_id);
    const max_bytes = 10000000; //maximum bytes in a level save file
    const string = try std.fs.cwd().readFileAlloc(a, path, max_bytes);

    if (!try std.json.validate(a, string)) {
        return error.invalid_json;
    }

    return try std.json.parseFromSlice(level.Level, a, string, .{ .allocate = .alloc_always });
}

pub fn writeLevel(a: std.mem.Allocator, l: level.Level, save_id: []const u8, level_id: []const u8) !void {
    l.ecs.prepForStringify(a);
    const string = try std.json.stringifyAlloc(a, l, .{});
    const path = try getLevelPath(a, save_id, level_id);
    var file = try std.fs.createFileAbsolute(path, .{});
    try file.writeAll(string);
}

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
    //var sentinel_string = try a.dupeZ(u8, string);
    //_ = sentinel_string;
    defer a.free(string);

    std.debug.print("parsing: {s}\n", .{string});

    if (std.mem.eql(u8, "toml", filename[(filename.len - 4)..])) {
        var parser = try zigtoml.parseContents(a, string);
        defer parser.deinit();

        var table = try parser.parse();
        defer table.deinit();

        var json = try table.stringify();
        defer json.deinit();

        return try std.json.parseFromSlice(T, a, json.items, .{ .allocate = .alloc_always });
    }

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
