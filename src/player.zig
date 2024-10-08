const std = @import("std");
const move = @import("movement.zig");
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

const dvui = @import("dvui");
const ray = @import("raylib-import.zig").ray;
pub fn updatePlayerSystem(
    self: *ecs.ECS,
    a: std.mem.Allocator,
    l: *Lua,
    window_manager: *const anime.WindowManager,
    opt: options.Update,
) !void {
    _ = opt; // autofix
    _ = l;
    const systems = [_]type{ Component.IsPlayer, Component.Physics };
    const set = self.getSystemDomain(a, &systems);

    for (set) |member| {
        var direction = ray.Vector2{ .x = 0, .y = 0 };

        if (window_manager.keybindings.isDown("player_up")) {
            direction.y -= 1;
        }

        if (window_manager.keybindings.isDown("player_down")) {
            direction.y += 1;
        }

        if (window_manager.keybindings.isDown("player_left")) {
            direction.x -= 1;
        }

        if (window_manager.keybindings.isDown("player_right")) {
            direction.x += 1;
        }

        var physics = self.get(Component.Physics, member);
        physics.applyForce(move.scaleVector(direction, 200));
        //physics.vel.x += direction.x * physics.acceleration * opt.dt;
        //physics.vel.y += direction.y * physics.acceleration * opt.dt;

        //let player shoot projectiles
        //if (window_manager.isMousePressed(.right) and window_manager.getMouseOwner() == .level) {
        //    //const fireball = try arch.createFireball(self, a);
        //    const fireball = try arch.createPotion(self, a);
        //    const pos = window_manager.getMouseTileCoordinates();
        //    self.setComponent(a, fireball, Component.Physics{
        //        .position = pos,
        //        .velocity = .{
        //            .x = (ecs.randomFloat() - 0.5) * opt.dt,
        //            .y = (ecs.randomFloat() - 0.5) * opt.dt,
        //        },
        //    }) catch |err| std.debug.print("error adding component to entity when spawning fireball {!}", .{err});
        //}

        ////spawnSlimes
        //if (window_manager.isMousePressed(.left) and window_manager.getMouseOwner() == .level) {
        //    //const slime = try l.autoCall(?usize, "SpawnSlime", .{ self, &copy }) orelse break;
        //    const slime = arch.createSlime(self, a) catch continue;
        //    const pos = window_manager.getMouseTileCoordinates();
        //    self.setComponent(a, slime, Component.Physics{
        //        .position = pos,
        //        .mass = 1,
        //    }) catch continue;
        //}
    }
}
