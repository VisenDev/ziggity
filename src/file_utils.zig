const std = @import("std");
const level = @import("level.zig");

//========PATHS========
pub fn getConfigDirPath(a: std.mem.Allocator) ![]const u8 {
    const cwd = try std.fs.selfExeDirPathAlloc(a);
    return try std.fmt.allocPrint(a, "{s}{s}", .{ cwd, "/config/" });
}

pub fn getSaveDirPath(a: std.mem.Allocator) ![]const u8 {
    const cwd = try std.fs.selfExeDirPathAlloc(a);
    return try std.fmt.allocPrint(a, "{s}{s}", .{ cwd, "/saves/" });
}

pub fn getLevelPath(a: std.mem.Allocator, save_id: []const u8, level_id: []const u8) ![]const u8 {
    const save_dir = try getSaveDirPath(a);
    return try std.fmt.allocPrint(a, "{s}{s}/levels/{s}.json", .{ save_dir, save_id, level_id });
}

//========LEVEL IO========
pub fn readLevel(a: std.mem.Allocator, save_id: []const u8, level_id: []const u8) !level.Level {
    const path = try getLevelPath(a, save_id, level_id);
    const string = try std.fs.cwd().readFileAlloc(a, path, 2048);
    const parsed = try std.json.parseFromSlice(level.Level, a, string, .{});
    return parsed;
}

pub fn writeLevel(a: std.mem.Allocator, l: level.Level, save_id: []const u8, level_id: []const u8) !void {
    const string = try std.json.stringifyAlloc(a, l, .{});
    const path = try getLevelPath(a, save_id, level_id);
    var file = try std.fs.createFileAbsolute(path, .{});
    try file.writeAll(string);
}

//========SAVE CREATION/DELETION========
pub fn createSaveDir(a: std.mem.Allocator, save_id: []const u8) !void {
    const save_dir = try getSaveDirPath(a);
    const new_save_path = try std.fmt.allocPrint(a, "{s}{s}", .{ save_dir, save_id });
    const new_save_levels_path = try std.fmt.allocPrint(a, "{s}/levels", .{new_save_path});
    try std.fs.makeDirAbsolute(new_save_path);
    try std.fs.makeDirAbsolute(new_save_levels_path);
}

pub fn deleteSaveDir(a: std.mem.Allocator, save_id: []const u8) !void {
    const save_dir = try getSaveDirPath(a);
    const condemned_save_path = try std.fmt.allocPrint(a, "{s}{s}", .{ save_dir, save_id });
    const new_hidden_save_path = try std.fmt.allocPrint(a, "{s}.{s}", .{ save_dir, save_id });
    std.fs.renameAbsolute(condemned_save_path, new_hidden_save_path);
}

pub const NewSaveOptions = struct {
    name: []const u8,
};

pub fn createNewSave(a: std.mem.Allocator, options: NewSaveOptions) !void {
    try createSaveDir(a, options.name);
    const biomes = [_]level.Level.Record{.{ .name = "cave", .weight = 10 }};
    const first_level = try level.Level.generate(a, .{ .name = "first_level", .biomes = &biomes });
    try writeLevel(a, first_level, options.name, "first_level");
}

//========CONFIG IO========
pub fn readConfig(comptime T: type, a: std.mem.Allocator, filename: []const u8) !T {
    const path = try getConfigDirPath(a);
    const string = try std.fs.cwd().readFileAlloc(a, path ++ filename, 2048);
    return try std.json.parseFromSlice(T, a, string, .{});
}
