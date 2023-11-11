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
    var ctx = getCtx(l) orelse return 0;

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
    var ctx = getCtx(l) orelse return 0;

    const fps = l.toInteger(-1) catch {
        processError(l, ctx.console);
        return 0;
    };

    ray.SetTargetFPS(@intCast(fps));
    return 0;
}

fn clear(l: *Lua) i32 {
    var ctx = getCtx(l) orelse return 0;

    ctx.console.clear();
    return 0;
}

fn log(l: *Lua) i32 {
    var ctx = getCtx(l) orelse return 0;

    const str = l.toString(-1) catch {
        processError(l, ctx.console);
        return 0;
    };

    var len = std.mem.indexOfSentinel(u8, 0, str);
    std.debug.print("\nlog message {s}\n", .{str[0..len]});

    ctx.console.log(str) catch {
        processError(l, ctx.console);
        return 0;
    };

    return 0;
}

///gets the ctx upvalue
fn getCtx(l: *Lua) ?*ApiContext {
    return l.toUserdata(ApiContext, Lua.upvalueIndex(1)) catch ctx: {
        const string = l.toString(-1) catch |err| blk: {
            std.debug.print("{!}\n", .{err});
            break :blk "unknown lua error";
        };
        std.debug.print("{s}\n", .{string});
        break :ctx null;
    };
}

///logs a error
fn processError(l: *Lua, console: *cmd.Console) void {
    const string = l.toString(-1) catch |err| blk: {
        std.debug.print("{!}\n", .{err});
        break :blk "unknown lua error";
    };

    console.log(string) catch |err| {
        std.debug.print("{!}\n", .{err});
    };
    if (l.getTop() > 1) {
        l.pop(1);
    }
}

const registry = struct {
    pub const lvl = [_]ziglua.FnReg{
        .{ .name = "spawnSlime", .func = ziglua.wrap(spawnSlime) },
    };
    pub const core = [_]ziglua.FnReg{
        .{ .name = "setFPS", .func = ziglua.wrap(setFPS) },
    };
    pub const console = [_]ziglua.FnReg{
        .{ .name = "clear", .func = ziglua.wrap(clear) },
        .{ .name = "log", .func = ziglua.wrap(log) },
    };
};

pub fn initLuaApi(a: std.mem.Allocator, context: *ApiContext) !Lua {
    var l = try Lua.init(a);
    l.openLibs();

    l.createTable(0, 0);
    l.setGlobal("api");
    l.setTop(0);

    _ = try l.getGlobal("api");

    inline for (comptime std.meta.declarations(registry)) |decl| {
        const name = try a.dupeZ(u8, decl.name);
        defer a.free(name);

        _ = l.pushString(name);
        try l.newMetatable(name);
        l.pushLightUserdata(context);
        l.setFuncs(&@field(registry, decl.name), 1);

        std.debug.assert(l.isTable(-1));
        std.debug.assert(l.isString(-2));
        std.debug.assert(l.isTable(1));
        l.setTable(1);
    }

    const program =
        \\function printTable(t)
        \\  for key, value in pairs(t) do
        \\      print("Key: " .. key.tostring() .. ", Value: " .. value.tostring())
        \\  end
        \\end
    ;
    try l.doString(program);

    return l;

    //try l.newMetatable("api");
    //l.pushLightUserdata(context);
    //_ = try l.setUpvalue(-2, -1);
    //l.setGlobal("api");
    ////l.setFuncs(&[_]ziglua.FnReg{}, 1);

    //// Create 'lvl' and 'core' subtables under 'api'
    //l.newTable();
    //l.setFuncs(&registry.lvl, 0);
    //l.setField(1, "lvl");

    //l.newTable();
    //l.setFuncs(&registry.core, 0);
    //l.setField(1, "core");

}
