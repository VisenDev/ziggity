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
    history: std.ArrayList(String),

    //raygui data
    rendering: bool = true,
    editing: bool = false,

    pub fn init(a: std.mem.Allocator) !Console {
        var cmd = String.init(a);
        try cmd.appendNTimes(0, max_command_len + 1);
        return .{
            .command = cmd,
            .history = std.ArrayList(String).init(a),
        };
    }

    pub fn deinit(self: *@This()) void {
        for (self.history.items) |str| {
            str.deinit();
        }
        self.history.deinit();
        self.command.deinit();
    }

    pub inline fn isPlayerTyping(self: *const @This()) bool {
        return self.editing;
    }

    pub inline fn isRendered(self: *const @This()) bool {
        return self.rendering;
    }

    pub fn run(self: *@This(), lua: *Lua, keys: key.KeyBindings) !void {
        //console render on or off
        if (keys.isPressed("console")) {
            self.rendering = !self.rendering;
        }

        //escape overwrite
        if (ray.IsKeyPressed(ray.KEY_ESCAPE)) {
            self.editing = false;
        }

        if (self.rendering) {
            const width: f32 = 216;
            const x: f32 = cam.screenWidth() - width;
            const height: f32 = cam.screenHeight();
            const line_height: f32 = 20;
            self.rendering = !(ray.GuiWindowBox(.{ .x = x, .y = 0, .width = width, .height = height }, "Console") != 0);

            var keep_active = false;
            if (self.editing and ray.IsKeyPressed(ray.KEY_ENTER)) {
                try self.history.append(try self.command.clone());
                keep_active = true;

                // Compile a line of Lua code
                const str = self.command.items;
                const len = max_command_len;
                lua.loadString(str[0..len :0]) catch {
                    std.debug.print("{s}\n", .{try lua.toString(-1)});
                    if (lua.getTop() > 1) {
                        lua.pop(1);
                    }
                };

                // Execute a line of Lua code
                lua.protectedCall(0, 0, 0) catch {
                    std.debug.print("{s}\n", .{try lua.toString(-1)});
                    if (lua.getTop() > 1) {
                        lua.pop(1);
                    }
                };

                self.command.items[0] = 0;
            }

            const pos = ray.Rectangle{ .x = x, .y = line_height, .width = width, .height = 24 };
            if (0 != ray.GuiTextBox(pos, self.command.items.ptr, @intCast(max_command_len), self.editing)) {
                self.editing = !self.editing;
            }

            if (keep_active) {
                self.editing = true;
            }

            for (self.history.items, 0..) |str, i| {
                const c_i: f32 = @floatFromInt(self.history.items.len - i - 1);
                if (c_i < height / line_height) {
                    _ = ray.GuiLabel(ray.Rectangle{ .x = x, .y = (c_i + 2) * line_height, .width = width, .height = line_height }, str.items.ptr);
                }
            }
        }
    }
};
