const ziglua = @import("ziglua");
const Lua = ziglua.Lua;
const ecs = @import("ecs.zig");
const level = @import("level.zig");
const cmd = @import("console.zig");
const std = @import("std");

const ray = @cImport({
    @cInclude("raylib.h");
});

pub fn initLuaApi(a: *const std.mem.Allocator) !Lua {
    var l = try Lua.init(a);
    l.openLibs();

    l.createTable(0, 0);
    l.setGlobal("api");

    const api = .{
        .console = .{
            .clear = cmd.Console.clear,
            .log = cmd.Console.log,
        },
        .lvl = .{
            .newEntity = ecs.ECS.newEntityPtr,
            .addComponent = ecs.ECS.addJsonComponent,
        },
    };

    _ = try l.getGlobal("api");
    inline for (@typeInfo(@TypeOf(api)).Struct.fields) |field| {
        _ = l.pushString(field.name ++ "");
        l.createTable(0, 0);

        inline for (@typeInfo(field.type).Struct.fields) |inner_field| {
            _ = l.pushString(inner_field.name ++ "");
            l.autoPushFunction(@field(@field(api, field.name), inner_field.name));

            std.debug.assert(l.isFunction(-1));
            std.debug.assert(l.isString(-2));
            std.debug.assert(l.isTable(-3));
            l.setTable(-3);
            l.setTop(3);
        }

        std.debug.assert(l.isTable(-1));
        std.debug.assert(l.isString(-2));
        std.debug.assert(l.isTable(-3));
        l.setTable(-3);
        l.setTop(1);
    }

    try l.doString(@embedFile("scripts/archetypes.lua"));
    try l.doString(@embedFile("scripts/procgen.lua"));

    return l;
}

const program =
    \\function printTable(t)
    \\  for key, value in pairs(t) do
    \\    if type(value) == "table" then
    \\      print("Key: " .. tostring(key))
    \\      printTable(value)
    \\    else
    \\      print("Key: " .. tostring(key) .. ", Value: " .. tostring(value))
    \\    end
    \\  end
    \\end
    \\
    \\local status, err = pcall(printTable, api)
    \\print(err)
;
