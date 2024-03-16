const std = @import("std");
const arch = @import("archetypes.zig");
const api = @import("api.zig");
const tile = @import("tiles.zig");
const anime = @import("animation.zig");
const map = @import("map.zig");
const texture = @import("textures.zig");
const key = @import("keybindings.zig");
const options = @import("options.zig");
const ecs = @import("ecs.zig");
const SparseSet = @import("sparse_set.zig").SparseSet;
const Grid = @import("grid.zig").Grid;
const coll = @import("collisions.zig");
const cam = @import("camera.zig");
const Lua = @import("ziglua").Lua;
pub const Component = @import("components.zig");
const intersection = @import("sparse_set.zig").intersection;
const ray = @cImport({
    @cInclude("raylib.h");
});

pub fn updatePlayerSystem(
    self: *ecs.ECS,
    a: std.mem.Allocator,
    l: *Lua,
    keys: key.KeyBindings,
    camera: ray.Camera2D,
    opt: options.Update,
) !void {
    const systems = [_]type{ Component.is_player, Component.physics };
    const set = self.getSystemDomain(a, &systems);

    const magnitude: f32 = 30;

    for (set) |member| {
        var direction = ray.Vector2{ .x = 0, .y = 0 };

        if (keys.isDown("player_up")) {
            direction.y -= magnitude;
        }

        if (keys.isDown("player_down")) {
            direction.y += magnitude;
        }

        if (keys.isDown("player_left")) {
            direction.x -= magnitude;
        }

        if (keys.isDown("player_right")) {
            direction.x += magnitude;
        }

        var physics = self.get(Component.physics, member);
        physics.vel.x += direction.x * physics.acceleration * opt.dt;
        physics.vel.y += direction.y * physics.acceleration * opt.dt;

        var copy = a; //mutable copy of the allocator parameter

        //let player shoot projectiles
        if (ray.IsMouseButtonDown(ray.MOUSE_BUTTON_LEFT)) {
            const fireball = try l.autoCall(?usize, "SpawnSlime", .{ self, &copy }) orelse break;
            const pos = cam.mousePos(camera);
            self.setComponent(a, fireball, Component.physics{
                .pos = pos,
                .vel = .{
                    .x = (ecs.randomFloat() - 0.5) * opt.dt,
                    .y = (ecs.randomFloat() - 0.5) * opt.dt,
                },
            }) catch |err| std.debug.print("error adding component to entity when spawning fireball {!}", .{err});
        }

        //spawnSlimes
        if (ray.IsMouseButtonDown(ray.MOUSE_BUTTON_RIGHT)) {
            //const slime = try l.autoCall(?usize, "SpawnSlime", .{ self, &copy }) orelse break;
            const slime = arch.createSlime(self, a) catch continue;
            const pos = cam.mousePos(camera);
            self.setComponent(a, slime, Component.physics{
                .pos = pos,
            }) catch continue;
        }
    }
}
