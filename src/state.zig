const tex = @import("textures.zig");
const std = @import("std");
const ent = @import("entity.zig");

const entity_cap = 2048;

pub const GameState = struct {
    t: tex.TextureState,
    e: ent.EntityState(entity_cap),
};

pub fn createGameState(a: std.mem.Allocator) !GameState {

    //initialization
    var t = try tex.createTextureState(a);
    var e = try ent.EntityState(entity_cap).init(a);
    //var map
    return GameState{
        .t = t,
        .e = e,
    };
}
