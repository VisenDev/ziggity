const std = @import("std");
const api = @import("api.zig");
const key = @import("keybindings.zig");
const cam = @import("camera.zig");
pub const Lua = @import("ziglua").Lua;

const ray = @cImport({
    @cInclude("raylib.h");
    @cInclude("raygui.h");
    @cInclude("style_dark.h");
});

const String = std.ArrayList(u8);

pub const Console = struct {
    const max_command_len: usize = 64;
    commands: std.ArrayList(String),
    command_index: usize = 0,
    history: std.ArrayList(String),
    allocator: std.mem.Allocator,

    //raygui data
    rendering: bool = false,
    editing: bool = false,
    skip_next_input: bool = false,

    pub fn init(a: std.mem.Allocator) !Console {
        var cmd = String.init(a);
        try cmd.appendNTimes(0, max_command_len + 1);
        var commands = std.ArrayList(String).init(a);
        try commands.append(cmd);
        return .{
            .commands = commands,
            .history = std.ArrayList(String).init(a),
            .allocator = a,
        };
    }

    pub fn deinit(self: *@This()) void {
        for (self.history.items) |str| {
            str.deinit();
        }
        self.history.deinit();

        for (self.commands.items) |str| {
            str.deinit();
        }
        self.commands.deinit();
    }

    pub inline fn isPlayerTyping(self: *const @This()) bool {
        return self.editing;
    }

    pub inline fn isRendered(self: *const @This()) bool {
        return self.rendering;
    }

    pub inline fn clear(self: *@This()) void {
        self.history.clearRetainingCapacity();
    }

    pub inline fn getRecentHistory(self: *@This(), count: usize) []const String {
        const len = self.history.items.len;
        if (count >= len) {
            return self.history.items[0..len];
        }

        return self.history.items[len - count .. len];
    }
    ///makes a copy, caller owns memory
    pub inline fn log(self: *@This(), value: [*:0]const u8) !void {
        var len = std.mem.indexOfSentinel(u8, 0, value);
        var string = String.init(self.allocator);
        try string.appendSlice(value[0 .. len + 1]);
        try self.history.append(string);
    }

    pub fn logFmt(self: *@This(), comptime fmt: []const u8, args: anytype) !void {
        var stringified = try std.fmt.allocPrintZ(self.allocator, fmt, args);
        var string = String.init(self.allocator);
        try string.appendSlice(stringified);
        try string.append(0);
        try self.history.append(string);
    }

    pub fn getTopCommand(self: *@This()) *String {
        return &self.commands.items[self.commands.items.len - 1];
    }

    ///clones the string, caller responsible for freeing the str
    pub fn setTopCommand(self: *@This(), str: String) !void {
        if (self.commands.items.len == 0) return error.NoTopCommand;

        self.getTopCommand().deinit();
        self.getTopCommand().* = try str.clone();
    }

    ///returns the indexed command
    pub inline fn getIndexedCommand(self: *@This()) String {
        return self.commands.items[self.command_index];
    }

    ///resets the index to point at the top item
    pub inline fn resetIndex(self: *@This()) void {
        self.command_index = self.commands.items.len - 1;
    }

    pub inline fn getCommandsLen(self: *@This()) usize {
        return self.commands.items.len;
    }

    pub inline fn getHistoryLen(self: *@This()) usize {
        return self.history.items.len;
    }

    pub fn update(self: *@This(), l: *Lua, keys: key.KeyBindings) !void {
        if (keys.isPressed("console")) {
            self.rendering = !self.rendering;
        }

        if (keys.isPressed("previous")) {
            if (self.command_index > 0) {
                self.command_index -= 1;
                if (self.command_index != self.commands.items.len - 1) {
                    try self.setTopCommand(self.getIndexedCommand());
                }
            }
        }

        if (keys.isPressed("next")) {
            if (self.command_index < self.commands.items.len - 1) {
                self.command_index += 1;
                if (self.command_index != self.commands.items.len - 1) {
                    try self.setTopCommand(self.getIndexedCommand());
                }
            } else {
                self.getTopCommand().items[0] = 0;
            }
        }

        if (keys.isPressed("insert_mode")) {
            self.rendering = true;
            self.editing = true;
            self.skip_next_input = true;
            self.resetIndex();
        }

        if (keys.isPressed("execute")) {
            const len = max_command_len;
            const str = self.commands.items[self.command_index].items[0..len :0];

            var new_command = String.init(self.allocator);
            try new_command.appendNTimes(0, max_command_len + 1);
            try self.commands.append(new_command);
            self.command_index = self.commands.items.len - 1;

            const history_len_before = self.getHistoryLen();
            l.loadString(str) catch {
                _ = api.handleLuaError(l);
                return;
            };
            l.protectedCall(0, 0, 0) catch {
                _ = api.handleLuaError(l);
                return;
            };

            if (history_len_before == self.getHistoryLen()) {
                try self.log("success!");
            }
        }
    }

    pub fn render(self: *@This()) !void {
        const x: f32 = 0;
        const line_height: f32 = 24;
        const y: f32 = cam.screenHeight() - line_height;
        const width: f32 = cam.screenWidth();

        if (!self.rendering) return;

        const input_position = ray.Rectangle{ .x = x, .y = y, .width = width, .height = line_height };
        if (!self.skip_next_input and self.editing) {
            if (0 != ray.GuiTextBox(input_position, self.getTopCommand().items.ptr, @intCast(max_command_len), self.editing)) {
                self.editing = !self.editing;
            }
        }
        self.skip_next_input = false;

        const len: usize = 10;
        for (self.getRecentHistory(len), 0..) |str, index| {
            const size: usize = if (len > self.getHistoryLen())
                self.getHistoryLen()
            else
                len;

            //std.debug.print("size: {}, index: {}\n", .{ size, index });
            const i: f32 = @floatFromInt(size - index);
            var line_y: f32 = y - (i * line_height);
            if (!self.editing) {
                line_y += line_height;
            }

            const log_position = ray.Rectangle{ .x = 0, .y = line_y, .width = width, .height = line_height };
            _ = ray.GuiLabel(log_position, str.items.ptr);
        }
    }
};

//==========Lua wrapper functions=========
pub fn luaClear(l: *Lua) i32 {
    var ctx = api.getCtx(l) orelse return 0;
    ctx.console.clear();
    return 0;
}

pub fn luaLog(l: *Lua) i32 {
    var ctx = api.getCtx(l) orelse return 0;

    const str = l.toString(-1) catch return api.handleLuaError(l);
    ctx.console.log(str) catch |err| return api.handleZigError(l, err);
    return 0;
}
