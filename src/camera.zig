pub const tile = @import("tiles.zig");
const Component = @import("components.zig");
pub const key = @import("keybindings.zig");
const ray = @cImport({
    @cInclude("raylib.h");
});
pub const std = @import("std");
pub const level = @import("level.zig");
const sys = @import("systems.zig");
const anime = @import("animation.zig");

pub fn screenWidth() f32 {
    return @floatFromInt(ray.GetScreenWidth());
}

pub fn screenHeight() f32 {
    return @floatFromInt(ray.GetScreenHeight());
}

fn tof32(input: anytype) f32 {
    return @floatFromInt(input);
}

pub inline fn initCamera() ray.Camera2D {
    return ray.Camera2D{
        .offset = .{ .x = 0, .y = 0 },
        .rotation = 0.0,
        .zoom = 1,
        .target = .{ .x = 0, .y = 0 },
    };
}

//every tile is scaled up to this resolution before rendering
pub const render_resolution = 64;

pub fn tileToScreen(tile_coordinates: ray.Vector2, camera: ray.Camera2D) ray.Vector2 {
    const world_position = tileToWorld(tile_coordinates);
    return ray.GetScreenToWorld2D(world_position, camera);
}

pub fn tileToWorld(tile_coordinates: ray.Vector2) ray.Vector2 {
    return ray.Vector2{
        .x = tile_coordinates.x * render_resolution,
        .y = tile_coordinates.y * render_resolution,
    };
}

//TODO update camera offset
pub fn calculateCameraPosition(
    camera: ray.Camera2D,
    l: level.Level,
    keybindings: *const key.KeyBindings,
) ray.Camera2D {
    var zoom = camera.zoom;
    if (keybindings.isDown("zoom_in") and zoom < 4.3) zoom *= 1.01;
    if (keybindings.isDown("zoom_out") and zoom > 0.7) zoom *= 0.99;

    const player_id = l.player_id;
    var player_position: ray.Vector2 = l.ecs.get(Component.Physics, player_id).pos;

    player_position.x *= tof32(render_resolution);
    player_position.y *= tof32(render_resolution);

    const min_camera_x: f32 = (screenWidth() / 2) / zoom;
    const min_camera_y: f32 = (screenHeight() / 2) / zoom;

    if (player_position.x < min_camera_x) {
        player_position.x = min_camera_x;
    }

    if (player_position.y < min_camera_y) {
        player_position.y = min_camera_y;
    }

    const map_width: f32 = (tof32(l.map.width * render_resolution));
    const map_height: f32 = (tof32(l.map.height * render_resolution));
    const max_camera_x: f32 = (map_width - min_camera_x);
    const max_camera_y: f32 = (map_height - min_camera_y);

    if (player_position.x > max_camera_x) {
        player_position.x = max_camera_x;
    }

    if (player_position.y > max_camera_y) {
        player_position.y = max_camera_y;
    }

    return ray.Camera2D{
        .offset = .{ .x = screenWidth() / 2, .y = screenHeight() / 2 },
        .rotation = 0.0,
        .zoom = zoom,
        .target = player_position,
    };
}

pub fn mousePos(camera: ray.Camera2D) ray.Vector2 {
    return anime.scaleVector(
        ray.GetScreenToWorld2D(ray.GetMousePosition(), camera),
        1.0 / @as(f32, @floatFromInt(render_resolution)),
    );
}

test "unit tests" {
    @import("std").testing.refAllDecls(@This());
}
