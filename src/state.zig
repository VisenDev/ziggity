//const tex = @import("textures.zig");
//const std = @import("std");
//const ent = @import("entity.zig");
//const map = @import("map.zig");
//const tile = @import("tiles.zig");
//
//const entity_cap = 2048;
//
//pub const State = struct {
//    texture_state: tex.TextureState,
//    entity_state: ent.EntityState(entity_cap),
//    map_state: map.MapState,
//    tile_state: tile.TileState,
//
//    pub fn init(a: std.mem.Allocator) !@This() {
//        var textures = try tex.createTextureState(a);
//        return .{
//            .texture_state = textures,
//            .entity_state = try ent.EntityState(entity_cap).init(a),
//            .map_state = try map.MapState.init(a),
//            .tile_state = try tile.TileState.init(a, textures),
//        };
//    }
//};
