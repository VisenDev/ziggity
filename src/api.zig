const ziglua = @import("ziglua");
const file = @import("file_utils.zig");
const ecs = @import("ecs.zig");
const level = @import("level.zig");
const cmd = @import("console.zig");
const std = @import("std");

const ray = @cImport({
    @cInclude("raylib.h");
});

pub fn getAbsPath() []u8 {
    var buffer: [1024]u8 = .{0} ** 1024;
    const path = std.fs.selfExeDirPath(&buffer) catch @panic("getAbsPath Failed");
    return buffer[0 .. path.len + 1];
}

pub fn initLuaApi(a: *const std.mem.Allocator) !*ziglua.Lua {
    var l = try ziglua.Lua.init(a);
    l.openLibs();

    try l.set("GetAbsPath", getAbsPath);

    //load the entry
    const entry = try file.getLuaEntryFile(a.*);
    defer a.free(entry);

    l.doFile(entry) catch |err| {
        const lua_err = try l.toString(-1);
        std.log.err("{s}", .{lua_err});
        return err;
    };

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
