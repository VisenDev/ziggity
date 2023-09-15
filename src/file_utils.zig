const std = @import("std");
const str = @import("str_utils.zig");
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
    const save_path = try getSavePath(a, save_id);
    return try std.fmt.allocPrint(a, "{s}levels/{s}.json", .{ save_path, level_id });
}

pub fn getSavePath(a: std.mem.Allocator, save_id: []const u8) ![]const u8 {
    const save_dir = try getSaveDirPath(a);
    return try std.fmt.allocPrint(a, "{s}{s}/", .{ save_dir, save_id });
}

//========LEVEL IO========
pub fn readLevel(a: std.mem.Allocator, save_id: []const u8, level_id: []const u8) !level.Level {
    const path = try getLevelPath(a, save_id, level_id);
    std.debug.print("LOADING LEVEL FROM: {s}\n", .{path});
    const string = try std.fs.cwd().readFileAlloc(a, path, 20000);
    const parsed = try std.json.parseFromSlice(level.Level, a, string, .{});
    return parsed.value;
}

pub fn writeLevel(a: std.mem.Allocator, l: level.Level, save_id: []const u8, level_id: []const u8) !void {
    const string = try std.json.stringifyAlloc(a, l, .{});
    const path = try getLevelPath(a, save_id, level_id);
    var file = try std.fs.createFileAbsolute(path, .{});
    try file.writeAll(string);
}

//========SAVE CREATION/DELETION========
//
//pub fn createSaveDir(a: std.mem.Allocator, save_id: []const u8) !void {
//    const new_save_path =
//    const new_save_levels_path = try std.fmt.allocPrint(a, "{s}/levels", .{new_save_path});
//    try std.fs.makeDirAbsolute(new_save_path);
//    try std.fs.makeDirAbsolute(new_save_levels_path);
//}

pub fn deleteSave(a: std.mem.Allocator, save_id: []const u8) !void {
    const save_dir = try getSaveDirPath(a);
    const condemned_save_path = try std.fmt.allocPrint(a, "{s}{s}", .{ save_dir, save_id });
    const new_hidden_save_path = try std.fmt.allocPrint(a, "{s}.{s}", .{ save_dir, save_id });
    std.fs.renameAbsolute(condemned_save_path, new_hidden_save_path);
}

pub const NewSaveOptions = struct {
    name: []const u8,
};

pub fn createSave(a: std.mem.Allocator, options: NewSaveOptions) !void {

    //Create directories
    const save_path = try getSavePath(a, options.name);
    const save_levels_path = try std.fmt.allocPrint(a, "{s}/levels", .{save_path});
    try std.fs.makeDirAbsolute(save_path);
    try std.fs.makeDirAbsolute(save_levels_path);

    //populate levels
    const biomes = [_]level.Level.Record{.{ .name = "cave", .weight = 10 }};
    const first_level = try level.Level.generate(a, .{ .name = "first_level", .biomes = &biomes });
    try writeLevel(a, first_level, options.name, "first_level");

    //record state
    const path = try std.fmt.allocPrint(a, "{s}state.json", .{save_path});
    var file = try std.fs.createFileAbsolute(path, .{});
    const state = SaveState{ .name = options.name, .current_level = "first_level" };
    //    const new_save_levels_path = try std.fmt.allocPrint(a, "{s}/levels", .{new_save_path});
    const state_string = try std.json.stringifyAlloc(a, state, .{});
    try file.writeAll(state_string);
}

pub const SaveState = struct {
    name: []const u8,
    current_level: []const u8,
};

pub fn readSaveState(a: std.mem.Allocator, save_id: []const u8) !SaveState {
    const save_path = try getSavePath(a, str.findNullTerminator(save_id));
    const path = try std.fmt.allocPrint(a, "{s}state.json", .{save_path});
    std.debug.print("READING SAVE STATE: {s}\n", .{path});

    const string = try std.fs.cwd().readFileAlloc(a, path, 2048);
    const parsed = try std.json.parseFromSlice(SaveState, a, string, .{});
    return parsed.value;
}

//========CONFIG IO========
pub fn readConfig(comptime T: type, a: std.mem.Allocator, filename: []const u8) !T {
    const path = try getConfigDirPath(a);
    const full_path = try std.fmt.allocPrint(a, "{s}{s}", .{ path, filename });
    //std.debug.print("\n\n{s}\n\n", .{full_path});
    const string = try std.fs.cwd().readFileAlloc(a, full_path, 2048);
    const data = try std.json.parseFromSlice(T, a, string, .{});
    return data.value;
}

test "config" {
    const Key = struct {
        char: u8,
        shift: bool = false,
        control: bool = false,
    };

    const KeyBindings = struct {
        player_up: Key,
        player_down: Key,
        player_left: Key,
        player_right: Key,
    };

    _ = try readConfig(KeyBindings, std.testing.allocator, "keybindings.json");
}
