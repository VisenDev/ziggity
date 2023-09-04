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
    return try std.fmt.allocPrint(a, "{s}{s}/{s}.json", .{ save_dir, save_id, level_id });
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
    file.writeAll(string);
}

//========SAVE CREATION/DELETION========
pub fn createSave(a: std.mem.Allocator, save_id: []const u8) !void {
    const save_dir = try getSaveDirPath(a);
    try std.fs.makeDirAbsolute(save_dir ++ save_id);
}

pub fn deleteSave(a: std.mem.Allocator, save_id: []const u8) !void {
    const save_dir = try getSaveDirPath(a);
    std.fs.renameAbsolute(save_dir ++ save_id, save_dir ++ "." ++ save_id);
}

//========CONFIG IO========
pub fn readConfig(comptime T: type, a: std.mem.Allocator, filename: []const u8) !T {
    const path = try getConfigDirPath(a);
    const string = try std.fs.cwd().readFileAlloc(a, path ++ filename, 2048);
    return try std.json.parseFromSlice(T, a, string, .{});
}
