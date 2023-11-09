const ziglua = @import("ziglua");
const Lua = ziglua.Lua;
const ecs = @import("ecs.zig");
const level = @import("level.zig");
const cmd = @import("console.zig");
const std = @import("std");

const ray = @cImport({
    @cInclude("raylib.h");
});

pub const ApiContext = struct {
    allocator: *const std.mem.Allocator,
    lvl: *level.Level,
    console: *cmd.Console,
};

fn spawnSlime(l: *Lua) i32 {
    var ctx = l.toUserdata(ApiContext, Lua.upvalueIndex(1)) catch return 0;

    for (0..2) |_| {
        const a = ctx.allocator.*;
        const slime_id = ctx.lvl.ecs.newEntity(a).?;

        ctx.lvl.ecs.addComponent(a, slime_id, ecs.Component.physics{ .pos = ecs.randomVector2(5, 5) }) catch return 0;
        ctx.lvl.ecs.addComponent(a, slime_id, ecs.Component.sprite{ .player = .{ .animation_name = "slime" } }) catch return 0;
        ctx.lvl.ecs.addComponent(a, slime_id, ecs.Component.hitbox{}) catch return 0;
        ctx.lvl.ecs.addComponent(a, slime_id, ecs.Component.wanderer{}) catch return 0;
        ctx.lvl.ecs.addComponent(a, slime_id, ecs.Component.health{}) catch return 0;
        ctx.lvl.ecs.addComponent(a, slime_id, ecs.Component.movement_particles{}) catch return 0;
    }

    return 0;
}

fn setFPS(l: *Lua) i32 {
    const fps = l.toInteger(-1) catch return 0;
    ray.SetTargetFPS(@intCast(fps));
    return 0;
}

const registry = [_]ziglua.FnReg{
    .{ .name = "spawnSlime", .func = ziglua.wrap(spawnSlime) },
    .{ .name = "setFPS", .func = ziglua.wrap(setFPS) },
};

pub fn initLuaApi(a: std.mem.Allocator, context: *ApiContext) !Lua {
    var l = try Lua.init(a);
    l.openLibs();

    try l.newMetatable("api");
    l.pushLightUserdata(context);
    l.setFuncs(&registry, 1);
    l.setGlobal("api");

    return l;
}

//fn spawnSlime(l: *Lua) i32 {
//    var a_ptr = l.toUserdata(std.mem.Allocator, -1) catch return 0;
//    var lvl = l.toUserdata(level.Level, -2) catch return 0;
//    var a = a_ptr.*;
//
//    for (0..25) |_| {
//        const slime_id = lvl.ecs.newEntity(a).?;
//
//        lvl.ecs.addComponent(a, slime_id, ecs.Component.physics{ .pos = ecs.randomVector2(50, 50) }) catch return 0;
//        lvl.ecs.addComponent(a, slime_id, ecs.Component.sprite{ .player = .{ .animation_name = "slime" } }) catch return 0;
//        lvl.ecs.addComponent(a, slime_id, ecs.Component.hitbox{}) catch return 0;
//        lvl.ecs.addComponent(a, slime_id, ecs.Component.wanderer{}) catch return 0;
//        lvl.ecs.addComponent(a, slime_id, ecs.Component.health{}) catch return 0;
//        lvl.ecs.addComponent(a, slime_id, ecs.Component.movement_particles{}) catch return 0;
//    }
//
//    return 0;
//}
//
//pub fn initLuaApi(a: *const std.mem.Allocator, lvl: *level.Level, console: *cmd.Console) !Lua {
//    var l = try Lua.init(a.*);
//    l.createTable(0, 0);
//    l.setGlobal("api");
//    l.setTop(0);
//
//    //Register variables
//    _ = try l.getGlobal("api");
//
//    _ = l.pushString("level");
//    l.pushLightUserdata(lvl);
//    l.setTable(1);
//
//    _ = l.pushString("allocator");
//    l.pushLightUserdata(@constCast(a));
//    l.setTable(1);
//
//    _ = l.pushString("console");
//    l.pushLightUserdata(console);
//    l.setTable(1);
//
//    l.setTop(0);
//
//    //register functions
//    _ = try l.getGlobal("api");
//    l.setFuncs(&registry, 0);
//
//    return l;
//}
