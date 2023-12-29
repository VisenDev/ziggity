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

//========API UTILITY FUNCTIONS==========

///gets the ctx upvalue
pub fn getCtx(l: *Lua) ?*ApiContext {
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
pub fn handleLuaError(l: *Lua) i32 {
    _ = l.getGlobal("api.console.log") catch |err| return handleZigError(l, err);
    l.protectedCall(1, 0, 0) catch |err| return handleZigError(l, err);
    return 0;
}

var buffer: [1024]u8 = undefined;
pub fn handleZigError(l: *Lua, err: anyerror) i32 {
    const error_buffer = std.fmt.bufPrintZ(&buffer, "Zig Error: {!}", .{err}) catch @panic("failed buffer print");
    _ = l.pushString(error_buffer);
    l.setGlobal("error_buffer");
    const program = "api.console.log(error_buffer)";
    l.doString(program) catch std.debug.print("{s}\n", .{&error_buffer});
    return 0;
}

const registry = struct {
    pub const lvl = [_]ziglua.FnReg{
        .{ .name = "newEntity", .func = ziglua.wrap(ecs.luaNewEntity) },
        .{ .name = "addComponent", .func = ziglua.wrap(ecs.luaAddComponent) },
    };
    pub const console = [_]ziglua.FnReg{
        .{ .name = "clear", .func = ziglua.wrap(cmd.luaClear) },
        .{ .name = "log", .func = ziglua.wrap(cmd.luaLog) },
    };
};

///Calls a lua spawnEntity function()
pub fn call(l: *Lua, function_name: [:0]const u8) !usize {
    _ = l.getGlobal(function_name) catch return error.function_does_not_exist;
    try l.protectedCall(0, 1, 0);
    const id = try l.toInteger(-1);
    l.setTop(0);
    return @intCast(id);
}

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
        \\
        \\function test()
        \\  api.console.log("Attemping to create new entity")
        \\  id = api.lvl.newEntity()
        \\  api.console.log("Attemping to add components")
        \\  api.lvl.addComponent(id, "physics")
        \\  api.lvl.addComponent(id, "wanderer")
        \\  api.lvl.addComponent(id, "health")
        \\  api.lvl.addComponent(id, "movement_particles")
        \\  api.lvl.addComponent(id, "hitbox")
        \\  api.lvl.addComponent(id, "sprite", [[
        \\      {"animation_player": {"animation_name": "slime"}}
        \\  ]])
        \\end
    ;

    const new =
        \\function spawnSlime(allocator, ecs) 
        \\  game.level.addComponent(ecs, allocator, id, "physics")
        \\end
    ;
    _ = new;

    try l.doString(program);
    try l.doString(@embedFile("scripts/archetypes.lua"));

    return l;
}
