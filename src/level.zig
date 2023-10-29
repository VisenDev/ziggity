const std = @import("std");
const anime = @import("animation.zig");
const map = @import("map.zig");
const texture = @import("textures.zig");
const tile = @import("tiles.zig");
const file = @import("file_utils.zig");
const key = @import("keybindings.zig");
const ecs = @import("ecs.zig");
//const event = @import("events.zig");
const ray = @cImport({
    @cInclude("raylib.h");
});
const json = std.json;

//pub const Assets = struct {
//    tile_state: tile.TileState,
//    texture_state: texture.TextureState,
//
//    pub fn init(a: std.mem.Allocator) !Assets {
//        const texture_state = try texture.TextureState.init(a);
//        return .{
//            .tile_state = try tile.TileState.init(a, texture_state),
//            .texture_state = texture_state,
//        };
//    }
//
//    pub fn deinit(self: *const @This(), a: std.mem.Allocator) void {
//        self.texture_state.deinit();
//        self.tile_state.deinit(a);
//    }
//};

pub const UpdateOptions = struct {
    keys: *const key.KeyBindings,
    dt: f32,
};

pub const Exit = struct {
    x: u32,
    y: u32,
    destination_id: []const u8,
};

pub const Record = struct {
    name: []const u8,
    weight: u32,
};

pub const LevelGenOptions = struct {
    name: []const u8,
    biomes: []const Record = &[_]Record{},
    density: f64 = 0.4,
    width: u32 = 50,
    height: u32 = 50,
};

pub const Level = struct {
    name: []const u8 = "",
    ecs: *ecs.ECS = undefined,
    map: *map.MapState = undefined,
    exits: []const Exit = &[_]Exit{},
    player_id: usize = 0,
};

pub fn generateLevel(a: std.mem.Allocator, options: LevelGenOptions) !Level {
    var tile_state = try tile.TileState.init(a);
    defer tile_state.deinit();

    var entities = try a.create(ecs.ECS);
    entities.* = try ecs.ECS.init(a, 5000);

    var world_map = try a.create(map.MapState);
    world_map.* = try map.MapState.generate(a, tile_state, options);

    var exits = try a.alloc(Exit, 1);
    exits[0] = Exit{ .x = 5, .y = 5, .destination_id = "first_level" };

    const player_id = entities.newEntity(a).?;
    try entities.addComponent(a, player_id, ecs.Component.physics{ .pos = .{ .x = 5, .y = 5 } });
    try entities.addComponent(a, player_id, ecs.Component.sprite{ .player = .{ .animation_name = "player" } });
    try entities.addComponent(a, player_id, ecs.Component.movement_particles{});
    try entities.addComponent(a, player_id, ecs.Component.is_player{});

    for (0..50) |_| {
        const slime_id = entities.newEntity(a).?;
        try entities.addComponent(a, slime_id, ecs.Component.physics{ .pos = ecs.randomVector2(50, 50) });
        try entities.addComponent(a, slime_id, ecs.Component.sprite{ .player = .{ .animation_name = "slime" } });
        try entities.addComponent(a, slime_id, ecs.Component.collider{});
        try entities.addComponent(a, slime_id, ecs.Component.wanderer{});
        try entities.addComponent(a, slime_id, ecs.Component.health{});
        try entities.addComponent(a, slime_id, ecs.Component.movement_particles{});
    }

    return Level{ .name = "harry truman", .ecs = entities, .map = world_map, .exits = exits, .player_id = player_id };
}

//        const texture_id = assets.texture_state.name_index.get("slime").?;
//        for (0..10) |i| {
//            _ = try entities.spawnEntity(a, .{
//                .position = .{ .pos = .{ .x = @floatFromInt(i), .y = @floatFromInt(i) }, .acceleration = @floatFromInt(i + 2) },
//                .renderer = .{ .texture_id = texture_id },
//                .hostile_ai = .{ .target_id = id },
//            });
//        }
//        try entities.audit();
//
//        return Level{ .name = options.name, .entities = entities, .map = world_map, .exits = &exits, .player_id = id };
//    }
//
////    pub fn update(self: *Level, a: std.mem.Allocator, opt: UpdateOptions) !void {
////        _ = a;
////        try player.updatePlayer(self.player_id, self.entities, opt);
////        try self.entities.update(opt);
////    }
//
//    pub fn render(self: Level, assets: Assets, options: texture.RenderOptions) !void {
//        self.map.render(assets.tile_state, options);
//        try self.entities.render(assets.texture_state, options);
//    }
//
//    pub fn deinit(self: *const @This(), a: std.mem.Allocator) void {
//        self.entities.deinit(a);
//        self.map.deinit(a);
//    }
//
//    pub fn getPlayerPosition(self: *const @This()) !ray.Vector2 {
//        return self.entities.getPosition(self.player_id) orelse error.invalid_player_id;
//    }
//};
//
//test "json" {
//    //    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
//    //    const level = Level.init(gpa.allocator());
//    //    const string = try json.stringifyAlloc(gpa.allocator(), level, .{});
//    //    std.debug.print("JSON: \n\n{s}\n\n\n", .{string});
//}
