const std = @import("std");

//combines two paths
pub fn combine(a: std.mem.Allocator, str1: []const u8, str2: []const u8) ![]const u8 {
    return try std.fmt.allocPrint(a, "{s}{s}", .{ str1, str2 });
}

pub fn getCWD(a: std.mem.Allocator) ![]const u8 {
    const cwd: []const u8 = try std.fs.selfExeDirPathAlloc(a);
    const folder = "/game-files/";
    const result: []const u8 = try std.fmt.allocPrint(a, "{s}{s}", .{ cwd, folder });
    return result;
}

pub fn getConfigDirPath(a: std.mem.Allocator) ![]const u8 {
    const cwd: []const u8 = try getCWD(a);
    defer a.free(cwd);
    return try combine(a, cwd, "config/");
}

test "cwd" {
    const res = try getConfigDirPath(std.testing.allocator);
    defer std.testing.allocator.free(res);
}
