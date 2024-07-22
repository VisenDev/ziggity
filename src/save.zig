const std = @import("std");
const texture = @import("textures.zig");
const tile = @import("tiles.zig");
const file = @import("file_utils.zig");
const level = @import("level.zig");
const err = @import("error.zig");
const Lua = @import("ziglua").Lua;

//
//pub const Manifest = struct {
//    const filename = "manifest.json";
//    active_level_id: []const u8,
//};
//
//pub const Save = struct {
//    keybindings: config.KeyBindings,
//    level_json: std.json.Parsed(level.Level), //level_json used to deinit the memory
//    level: level.Level,
//    //    events: event.EventState,
//    save_id: []const u8,
//
//    pub fn load(a: std.mem.Allocator, save_id: []const u8) !*@This() {
//        const save_path = try file.getSavePath(a, save_id);
//        defer a.free(save_path);
//        const path = try file.combine(a, save_path, Manifest.filename);
//        defer a.free(path);
//        const string = try std.fs.cwd().readFileAlloc(a, path, 2048);
//        defer a.free(string);
//        const parsed = try std.json.parseFromSlice(Manifest, a, string, .{});
//
//        const save_record = parsed.value;
//        var level_json = try file.readLevel(a, save_id, save_record.active_level_id);
//        var result = try a.create(@This());
//
//        result.* = .{
//            .level_json = level_json,
//            .level = level_json.value,
//            .keybindings = try config.KeyBindings.init(a),
//            .save_id = save_id,
//            //         .events = events,
//        };
//
//        return result;
//    }
//
//    pub fn deinit(self: *@This(), a: std.mem.Allocator) void {
//        _ = a;
//        self.level_json.deinit();
//    }
//
//    pub fn delete(a: std.mem.Allocator, save_id: []const u8) !void {
//        //TODO rework this
//        const save_dir = try file.getSaveDirPath(a);
//        const condemned_save_path = try std.fmt.allocPrint(a, "{s}{s}", .{ save_dir, save_id });
//        const new_hidden_save_path = try std.fmt.allocPrint(a, "{s}.{s}", .{ save_dir, save_id });
//        std.fs.renameAbsolute(condemned_save_path, new_hidden_save_path);
//    }
//
//    pub fn create(a: std.mem.Allocator, assets: level.Assets, options: NewSaveOptions) !void {
//
//        //Create directories
//        const save_path = try file.getSavePath(a, options.name);
//        defer a.free(save_path);
//        const save_levels_path = try std.fmt.allocPrint(a, "{s}/levels", .{save_path});
//        defer a.free(save_levels_path);
//        try std.fs.makeDirAbsolute(save_path);
//        try std.fs.makeDirAbsolute(save_levels_path);
//
//        //populate levels
//        const first_level_id = "level_1";
//
//        const biomes = [_]level.Record{.{ .name = "cave", .weight = 10 }};
//        const first_level = try level.Level.generate(a, assets, .{ .name = first_level_id, .biomes = &biomes });
//        defer first_level.deinit(a);
//        try file.writeLevel(a, first_level, options.name, first_level_id);
//
//        //create the save manifest file
//        const manifest = Manifest{ .active_level_id = first_level_id };
//        const manifest_string = try std.json.stringifyAlloc(a, manifest, .{});
//        defer a.free(manifest_string);
//
//        const manifest_path = try std.fmt.allocPrint(a, "{s}{s}", .{ save_path, Manifest.filename });
//        defer a.free(manifest_path);
//        var manifest_file = try std.fs.createFileAbsolute(manifest_path, .{});
//        try manifest_file.writeAll(manifest_string);
//    }
//};
