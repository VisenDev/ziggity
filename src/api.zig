const ziglua = @import("ziglua");
const file = @import("file_utils.zig");
const ecs = @import("ecs.zig");
const level = @import("level.zig");
const cmd = @import("console.zig");
const std = @import("std");

const ray = @cImport({
    @cInclude("raylib.h");
});

var buffer: [1024]u8 = .{0} ** 1024;
pub fn getAbsPath() []const u8 {
    std.debug.print("get abs path called\n", .{});
    return std.fs.selfExeDirPath(&buffer) catch @panic("getAbsPath Failed");
}

pub fn loadFile(l: *ziglua.Lua, path: []const u8) !void {
    const fullpath = try file.combineAppendSentinel(l.allocator(), try file.getCWD(l.allocator()), path);
    try l.doFile(fullpath);
}

pub fn initLuaApi(a: *const std.mem.Allocator) !*ziglua.Lua {
    var l = try ziglua.Lua.init(a);
    l.openLibs();

    try l.set("ZigLuaStatePtr", l);
    try l.set("ZigLoadFile", loadFile);

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
