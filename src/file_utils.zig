const std = @import("std");
const level = @import("level.zig");

//const ztoml = @import("ztoml");
//const zigtoml = @import("toml");
const Lua = @import("ziglua").Lua;
const ziglua = @import("ziglua");

pub fn getLuaEntryFile(a: std.mem.Allocator) ![:0]const u8 {
    const lua_entry_file = "lua/init.lua";
    return try combineAppendSentinel(a, try getCWD(a), lua_entry_file);
}

//combines two paths
pub fn combine(a: std.mem.Allocator, str1: []const u8, str2: []const u8) ![]const u8 {
    return try std.fmt.allocPrint(a, "{s}{s}", .{ str1, str2 });
}

pub fn combineAppendSentinel(a: std.mem.Allocator, str1: []const u8, str2: []const u8) ![:0]const u8 {
    return try std.fmt.allocPrintZ(a, "{s}{s}", .{ str1, str2 });
}

//========DIR PATHS========
pub fn getCWD(a: std.mem.Allocator) ![]const u8 {
    const cwd: []u8 = try std.fs.selfExeDirPathAlloc(a);
    const folder = "/data/";
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
    return try std.fmt.allocPrint(a, "{s}levels/{s}.json.zlib", .{ save_path, level_id });
}

pub fn getSavePath(a: std.mem.Allocator, save_id: []const u8) ![]const u8 {
    const save_dir = try getSaveDirPath(a);
    defer a.free(save_dir);
    return try std.fmt.allocPrint(a, "{s}{s}/", .{ save_dir, save_id });
}

//const AllocWriter = struct {
//    data: std.ArrayList(u8),
//
//    pub fn init(a: std.mem.Allocator) AllocWriter {
//        return .{ .data = std.ArrayList(u8).init(a) };
//    }
//
//    fn writeFn(ctx: *const anyopaque, bytes: []u8) !usize {
//        var self: *AllocWriter = @ptrCast(ctx);
//        try self.data.appendSlice(bytes);
//        return bytes.len;
//    }
//
//    pub fn reader(self: *AllocWriter) std.io.AnyWriter {
//        return .{
//            .context = self,
//            .writeFn = writeFn,
//        };
//    }
//
//    pub fn deinit(self: *AllocWriter) void {
//        self.data.deinit();
//    }
//};

//========LEVEL IO========
pub fn readLevel(a: std.mem.Allocator, save_id: []const u8, level_id: []const u8) !std.json.Parsed(level.Level) {
    const file_path = try getLevelPath(a, save_id, level_id);
    defer a.free(file_path);

    const file_handle = try std.fs.openFileAbsolute(file_path, .{ .mode = .read_write });
    defer file_handle.close();

    var string = std.ArrayList(u8).init(a);
    defer string.deinit();

    try std.compress.zlib.decompress(file_handle.reader(), string.writer());
    return try std.json.parseFromSlice(level.Level, a, string.items, .{ .allocate = .alloc_always });
}

pub fn writeLevel(a: std.mem.Allocator, l: level.Level, save_id: []const u8, level_id: []const u8) !void {
    const file_path = try getLevelPath(a, save_id, level_id);
    defer a.free(file_path);

    var file_handle = try std.fs.createFileAbsolute(file_path, .{});
    defer file_handle.close();

    l.ecs.prepForStringify(a);

    const string = try std.json.stringifyAlloc(a, l, .{ .emit_null_optional_fields = false });
    defer a.free(string);

    var reader = std.io.fixedBufferStream(string);

    try std.compress.zlib.compress(reader.reader(), file_handle.writer(), .{ .level = .best });
}

//========CONFIG IO========
pub fn toSlice(str: [*c]u8) []u8 {
    const len = std.mem.indexOfSentinel(u8, 0, str);
    return str[0..len];
}

pub const ConfigType = enum {
    animations,
    tiles,
    keybindings,
};

pub fn readConfig(comptime ReturnType: type, lua: *Lua, config: ConfigType) !ziglua.Parsed(ReturnType) {
    const function_name = switch (config) {
        .animations => "Animations",
        .tiles => "Tiles",
        .keybindings => "keybindings",
    };

    return try lua.autoCall(ReturnType, function_name, .{});
}

//pub fn readConfig(comptime T: type, a: std.mem.Allocator, filename: []const u8) !std.json.Parsed(T) {
//    const path = try getConfigDirPath(a);
//    defer a.free(path);
//
//    const full_path = try std.fmt.allocPrint(a, "{s}{s}", .{ path, filename });
//    defer a.free(full_path);
//
//    const string = try std.fs.cwd().readFileAlloc(a, full_path, 12048);
//    //var sentinel_string = try a.dupeZ(u8, string);
//    //_ = sentinel_string;
//    defer a.free(string);
//
//    std.debug.print("parsing: {s}\n", .{string});
//
//    if (std.mem.eql(u8, "toml", filename[(filename.len - 4)..])) {
//        var parser = try zigtoml.parseContents(a, string);
//        defer parser.deinit();
//
//        var table = try parser.parse();
//        defer table.deinit();
//
//        var json = try table.toJson();
//        defer json.deinit();
//
//        return try std.json.parseFromSlice(T, a, json.items, .{ .allocate = .alloc_always });
//    }
//
//    return try std.json.parseFromSlice(T, a, string, .{ .allocate = .alloc_always });
//}

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
