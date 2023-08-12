const tex = @import("textures.zig");
const std = @import("std");
const ent = @import("entity.zig");

const entity_cap = 2048;

pub const GameState = struct {
    texture_state: tex.TextureState,
    entity_state: ent.EntityState(entity_cap),
};

pub fn createGameState(a: std.mem.Allocator) !GameState {
    return GameState{
        .texture_state = try tex.createTextureState(a),
        .entity_state = try ent.EntityState(entity_cap).init(a),
    };
}
