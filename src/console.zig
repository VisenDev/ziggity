const std = @import("std");
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
    command: String,
    command_log: std.ArrayList(String),
    command_log_index: usize = 0,
    history: std.ArrayList(String),
    allocator: std.mem.Allocator,

    //raygui data
    rendering: bool = false,
    editing: bool = false,

    pub fn init(a: std.mem.Allocator) !Console {
        var cmd = String.init(a);
        try cmd.appendNTimes(0, max_command_len + 1);
        return .{
            .command = cmd,
            .history = std.ArrayList(String).init(a),
            .command_log = std.ArrayList(String).init(a),
            .allocator = a,
        };
    }

    pub fn deinit(self: *@This()) void {
        for (self.history.items) |str| {
            str.deinit();
        }
        self.history.deinit();
        self.command.deinit();
        self.command_log.deinit();
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

    ///makes a copy, caller owns memory
    pub inline fn log(self: *@This(), value: [*:0]const u8) !void {
        var len = std.mem.indexOfSentinel(u8, 0, value);
        std.debug.print("\nlog message in console {s}\n", .{value[0..len]});

        var string = String.init(self.allocator);
        try string.appendSlice(value[0 .. len + 1]);
        try self.history.append(string);
    }

    pub fn run(self: *@This(), lua: *Lua, keys: key.KeyBindings) !void {
        //console render on or off
        if (keys.isPressed("console")) {
            self.rendering = !self.rendering;
        }

        //TODO finish implementing
        //if (keys.isPressed("previous")) {
        //    if (self.command_log_index < self.command_log.items.len) {
        //        self.command.deinit();
        //        self.command = try self.command_log.items[self.command_log_index].clone();
        //        self.command_log_index += 1;
        //    }
        //}

        //if (keys.isPressed("next")) {
        //    if (self.command_log_index > 0) {
        //        self.command.deinit();
        //        self.command = try self.command_log.items[self.command_log_index].clone();
        //        self.command_log_index -= 1;
        //    }
        //}

        var keep_active = false;

        //enter insert mode
        if (keys.isPressed("insert_mode")) {
            self.rendering = true;
            keep_active = true;
        }

        if (!self.rendering) return;

        const x: f32 = 0;
        const line_height: f32 = 24;
        const y: f32 = cam.screenHeight() - line_height;
        //const height: f32 = cam.screenHeight();
        const width: f32 = cam.screenWidth();
        self.rendering = true; //(ray.GuiWindowBox(.{ .x = x, .y = 0, .width = width, .height = height }, "Console") != 0);

        if (self.editing and ray.IsKeyPressed(ray.KEY_ENTER)) {
            self.command_log_index = 0;

            try self.command_log.append(try self.command.clone());
            keep_active = true;

            // Compile a line of Lua code
            const str = self.command.items;
            const len = max_command_len;
            lua.loadString(str[0..len :0]) catch {
                //std.debug.print("{s}\n", .{try lua.toString(-1)});
                try self.log(try lua.toString(-1));
                if (lua.getTop() > 1) {
                    lua.pop(1);
                }
            };

            // Execute a line of Lua code
            lua.protectedCall(0, 0, 0) catch {
                try self.log(try lua.toString(-1));
                if (lua.getTop() > 1) {
                    lua.pop(1);
                }
            };

            self.command.items[0] = 0;
        }

        const input_position = ray.Rectangle{ .x = x, .y = y, .width = width, .height = line_height };
        if (0 != ray.GuiTextBox(input_position, self.command.items.ptr, @intCast(max_command_len), self.editing)) {
            self.editing = !self.editing;
        }

        if (keep_active) {
            self.editing = true;
        }

        var num_lines_used: usize = 0;
        const max_lines: usize = 10;
        for (self.history.items, 0..) |str, i| {
            if (i > max_lines) break;
            const len = self.history.items.len;
            const log_position = ray.Rectangle{
                .x = 0,
                .y = cam.screenHeight() - (@as(f32, @floatFromInt(len - (i % max_lines) - num_lines_used)) * line_height) - line_height,
                .width = 3 * width,
                .height = line_height,
            };
            num_lines_used = @intCast(ray.GuiLabel(log_position, str.items.ptr));
            if (num_lines_used > 1) {
                num_lines_used -= 1;
            }
        }
    }
};
