const anime = @import("animation.zig");
const std = @import("std");
const light = @import("light.zig");
const ai = @import("ai.zig");
const inv = @import("inventory.zig");
const Component = @import("components.zig");
const control = @import("controller.zig");
const sys = @import("systems.zig");
const options = @import("options.zig");
const ECS = @import("ecs.zig").ECS;
const ray = @cImport({
    @cInclude("raylib.h");
});

pub const fireball = struct {
    pub fn do(item_id: usize, ecs: *ECS, window_manager: *anime.WindowManager, opt: options.Update) !void {
        //std.debug.print("fireball action called\n", .{});
        _ = window_manager; // autofix
        _ = item_id; // autofix
        _ = ecs; // autofix
        _ = opt; // autofix
    }
};

pub const spawn_slime = struct {
    pub fn do(item_id: usize, ecs: *ECS, window_manager: *anime.WindowManager, opt: options.Update) !void {
        //std.debug.print("spawn slime action called\n", .{});
        _ = window_manager; // autofix
        _ = item_id; // autofix
        _ = ecs; // autofix
        _ = opt; // autofix
    }
};
