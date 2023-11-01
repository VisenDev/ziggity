pub const tile = @import("tiles.zig");
pub const key = @import("keybindings.zig");
const ray = @cImport({
    @cInclude("raylib.h");
});
pub const std = @import("std");
pub const level = @import("level.zig");
const sys = @import("systems.zig");

fn screenWidth() f32 {
    return @floatFromInt(ray.GetScreenWidth());
}

fn screenHeight() f32 {
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

//TODO update camera offset
pub fn calculateCameraPosition(
    camera: ray.Camera2D,
    l: level.Level,
    tile_state: *const tile.TileState,
    keybindings: *const key.KeyBindings,
) ray.Camera2D {
    var zoom = camera.zoom;
    if (keybindings.zoom_in.pressed() and zoom < 4.3) zoom *= 1.01;
    if (keybindings.zoom_out.pressed() and zoom > 0.7) zoom *= 0.99;

    const player_id = l.player_id;
    var player_position: ray.Vector2 = l.ecs.components.physics.get(player_id).?.pos;

    player_position.x *= tof32(tile_state.resolution);
    player_position.y *= tof32(tile_state.resolution);

    const min_camera_x: f32 = (screenWidth() / 2) / zoom;
    const min_camera_y: f32 = (screenHeight() / 2) / zoom;

    if (player_position.x < min_camera_x) {
        player_position.x = min_camera_x;
    }

    if (player_position.y < min_camera_y) {
        player_position.y = min_camera_y;
    }

    const map_width: f32 = (tof32(l.map.width * tile_state.resolution));
    const map_height: f32 = (tof32(l.map.height * tile_state.resolution));
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

pub fn mousePos(camera: ray.Camera2D, tile_state_resolution: usize) ray.Vector2 {
    return sys.scaleVector(
        ray.GetScreenToWorld2D(ray.GetMousePosition(), camera),
        1.0 / @as(f32, @floatFromInt(tile_state_resolution)),
    );
}

test "unit tests" {
    @import("std").testing.refAllDecls(@This());
}
