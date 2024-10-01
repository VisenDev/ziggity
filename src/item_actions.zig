const anime = @import("animation.zig");
const arch = @import("archetypes.zig");
const move = @import("movement.zig");
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
    pub fn run(a: std.mem.Allocator, item_id: usize, ecs: *ECS, wm: *anime.WindowManager, opt: options.Update) void {
        const systems = [_]type{ Component.IsPlayer, Component.Physics };
        const set = ecs.getSystemDomain(a, &systems);
        const player = set[0];

        const physics = ecs.get(Component.Physics, player);
        const mouse_pos = wm.getMouseTileCoordinates();

        const angle = move.getAngleBetween(physics.pos, mouse_pos);

        var fireball_physics: Component.Physics = .{
            .position = physics.pos,
            .mass = 0.001,
        };
        const base_force: ray.Vector2 = .{ .x = 100, .y = 0 };
        fireball_physics.applyForce(move.rotateVector2(base_force, angle, .{ .x = 0, .y = 0 }));

        const fireball_id = arch.createFireball(ecs, a);
        ecs.setComponent(a, fireball_id, fireball_physics);

        //std.debug.print("fireball action called\n", .{});
        _ = item_id; // autofix
        _ = opt; // autofix
    }
};

pub const spawn_slime = struct {
    pub fn run(a: std.mem.Allocator, item_id: usize, ecs: *ECS, wm: *anime.WindowManager, opt: options.Update) void {
        _ = a; // autofix
        _ = wm; // autofix
        //std.debug.print("spawn slime action called\n", .{});
        _ = item_id; // autofix
        _ = ecs; // autofix
        _ = opt; // autofix
    }
};
