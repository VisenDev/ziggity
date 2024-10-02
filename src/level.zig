const std = @import("std");
const item = @import("item_actions.zig");
const arch = @import("archetypes.zig");
const Lua = @import("ziglua").Lua;
const anime = @import("animation.zig");
const MapState = @import("map.zig").MapState;
const texture = @import("textures.zig");
const tile = @import("tiles.zig");
const file = @import("file_utils.zig");
const key = @import("keybindings.zig");
const ecs = @import("ecs.zig");
const ray = @cImport({
    @cInclude("raylib.h");
});

pub const LevelGenOptions = struct {
    seed: usize = 0,
    level_id: []const u8,
    save_id: []const u8,
    width: u32 = 50,
    height: u32 = 50,
};

pub const Level = struct {
    level_id: []const u8 = "",
    save_id: []const u8 = "",
    ecs: *ecs.ECS,
    map: *MapState,

    pub fn read(a: std.mem.Allocator, save_id: []const u8, level_id: []const u8) !std.json.Parsed(Level) {
        const file_path = try file.getLevelPath(a, save_id, level_id);
        defer a.free(file_path);

        const file_handle = try std.fs.openFileAbsolute(file_path, .{ .mode = .read_write });
        defer file_handle.close();

        var string = std.ArrayList(u8).init(a);
        defer string.deinit();

        try std.compress.zlib.decompress(file_handle.reader(), string.writer());
        const result = try std.json.parseFromSlice(Level, a, string.items, .{ .allocate = .alloc_always });
        std.debug.assert(std.mem.eql(u8, result.value.level_id, level_id));
        std.debug.assert(std.mem.eql(u8, result.value.save_id, save_id));

        std.debug.print("[  \"{s}\" Successfully Read From Directory \"{s}\"  ]\n", .{ result.value.level_id, result.value.save_id });
        return result;
    }

    pub fn save(self: *const Level, a: std.mem.Allocator) !void {
        const file_path = try file.getLevelPath(a, self.save_id, self.level_id);
        defer a.free(file_path);

        var file_handle = try std.fs.createFileAbsolute(file_path, .{});
        defer file_handle.close();

        self.ecs.prepForStringify(a);

        const string = try std.json.stringifyAlloc(a, self, .{ .emit_null_optional_fields = false });
        defer a.free(string);

        var reader = std.io.fixedBufferStream(string);

        try std.compress.zlib.compress(reader.reader(), file_handle.writer(), .{ .level = .best });

        std.debug.print("[  \"{s}\"  Successfully Saved To Directory \"{s}\"  ]\n", .{ self.level_id, self.save_id });
    }

    pub fn generate(a: std.mem.Allocator, lua: *Lua, options: LevelGenOptions) !Level {
        var tile_state = try tile.TileState.init(a, lua);
        defer tile_state.deinit();

        var entities = try a.create(ecs.ECS);
        entities.* = try ecs.ECS.init(a, 10000);

        const world_map = try a.create(MapState);
        world_map.* = try MapState.generate(a, &tile_state, options);

        const player_id = try arch.createPlayer(entities, a);
        try entities.setComponent(a, player_id, ecs.Component.Physics{ .position = .{ .x = 3, .y = 5 } });

        var wand_id = try item.FireballWand.create(entities, a);
        try entities.setComponent(a, wand_id, ecs.Component.Physics{ .position = .{ .x = 3, .y = 5 } });

        wand_id = try item.SlimeWand.create(entities, a);
        try entities.setComponent(a, wand_id, ecs.Component.Physics{ .position = .{ .x = 3, .y = 5 } });

        wand_id = try item.ItemWand.create(entities, a);
        try entities.setComponent(a, wand_id, ecs.Component.Physics{ .position = .{ .x = 3, .y = 5 } });

        return Level{
            .level_id = options.level_id,
            .save_id = options.save_id,
            .ecs = entities,
            .map = world_map,
        };
    }
};

pub const NewSaveOptions = struct {
    save_id: []const u8,
    seed: usize,
};

pub fn createNewSave(a: std.mem.Allocator, lua: *Lua, options: NewSaveOptions) !void {

    //Create directories
    const save_path = try file.getSavePath(a, options.save_id);
    defer a.free(save_path);
    const save_levels_path = try std.fmt.allocPrint(a, "{s}/levels", .{save_path});
    defer a.free(save_levels_path);
    try std.fs.makeDirAbsolute(save_path);
    try std.fs.makeDirAbsolute(save_levels_path);

    //populate levels
    var arena = std.heap.ArenaAllocator.init(a);
    defer arena.deinit();

    const level_id = "level_1";
    const level = try Level.generate(arena.allocator(), lua, .{ .level_id = level_id, .save_id = options.save_id, .seed = options.seed });
    try level.save(a);

    //try file.writeLevel(a, first_level, options.name, first_level_id);

    //create the save manifest file
    const manifest = file.Manifest{ .active_level_id = level_id };
    const manifest_string = try std.json.stringifyAlloc(a, manifest, .{});
    defer a.free(manifest_string);

    const manifest_path = try std.fmt.allocPrint(a, "{s}{s}", .{ save_path, file.Manifest.filename });
    defer a.free(manifest_path);
    var manifest_file = try std.fs.createFileAbsolute(manifest_path, .{});
    try manifest_file.writeAll(manifest_string);
}
