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
//
//pub fn screenWidth() f32 {
//    return @floatFromInt(ray.GetScreenWidth());
//}
//
//pub fn screenHeight() f32 {
//    return @floatFromInt(ray.GetScreenHeight());
//}
//
//pub fn tof32(input: anytype) f32 {
//    return @floatFromInt(input);
//}
//
//pub fn scaleVector(a: ray.Vector2, scalar: anytype) ray.Vector2 {
//    if (@TypeOf(scalar) == f32)
//        return .{ .x = a.x * scalar, .y = a.y * scalar };
//
//    return .{ .x = a.x * tof32(scalar), .y = a.y * tof32(scalar) };
//}
//
//pub inline fn initCamera() ray.Camera2D {
//    return ray.Camera2D{
//        .offset = .{ .x = 0, .y = 0 },
//        .rotation = 0.0,
//        .zoom = 1,
//        .target = .{ .x = 0, .y = 0 },
//    };
//}
//
/////converts a position in the tilemap to where it will be rendered on the screen
//pub fn tileToScreen(tile_coordinates: ray.Vector2, camera: ray.Camera2D, animation_state: *const anime.AnimationState) ray.Vector2 {
//    const world_position = ray.Vector2{
//        .x = tile_coordinates.x * animation_state.tilemap_resolution,
//        .y = tile_coordinates.y * animation_state.tilemap_resolution,
//    };
//    return ray.GetWorldToScreen2D(world_position, camera);
//}
//
////pub fn tileToWorld(tile_coordinates: ray.Vector2) ray.Vector2 {
////    return ray.Vector2{
////        .x = tile_coordinates.x * render_resolution,
////        .y = tile_coordinates.y * render_resolution,
////    };
////}
//
////TODO update camera offset
//pub fn calculateCameraPosition(
//    camera: ray.Camera2D,
//    l: level.Level,
//    keybindings: *const key.KeyBindings,
//    animation_state: *const anime.AnimationState,
//) ray.Camera2D {
//    var zoom = camera.zoom;
//    if (keybindings.isDown("zoom_in") and zoom < 4.3) zoom *= 1.01;
//    if (keybindings.isDown("zoom_out") and zoom > 0.7) zoom *= 0.99;
//
//    const player_id = l.player_id;
//    var player_position: ray.Vector2 = l.ecs.get(Component.Physics, player_id).pos;
//
//    player_position.x *= animation_state.tilemap_resolution;
//    player_position.y *= animation_state.tilemap_resolution;
//
//    const min_camera_x: f32 = (screenWidth() / 2) / zoom;
//    const min_camera_y: f32 = (screenHeight() / 2) / zoom;
//
//    if (player_position.x < min_camera_x) {
//        player_position.x = min_camera_x;
//    }
//
//    if (player_position.y < min_camera_y) {
//        player_position.y = min_camera_y;
//    }
//
//    const map_width: f32 = tof32(l.map.width) * animation_state.tilemap_resolution;
//    const map_height: f32 = tof32(l.map.height) * animation_state.tilemap_resolution;
//    const max_camera_x: f32 = (map_width - min_camera_x);
//    const max_camera_y: f32 = (map_height - min_camera_y);
//
//    if (player_position.x > max_camera_x) {
//        player_position.x = max_camera_x;
//    }
//
//    if (player_position.y > max_camera_y) {
//        player_position.y = max_camera_y;
//    }
//
//    return ray.Camera2D{
//        .offset = .{ .x = screenWidth() / 2, .y = screenHeight() / 2 },
//        .rotation = 0.0,
//        .zoom = zoom,
//        .target = player_position,
//    };
//}
//
//pub fn mousePos(camera: ray.Camera2D, animation_state: *const anime.AnimationState) ray.Vector2 {
//    return anime.scaleVector(
//        ray.GetScreenToWorld2D(ray.GetMousePosition(), camera),
//        1.0 / animation_state.tilemap_resolution,
//    );
//}
//
//test "unit tests" {
//    @import("std").testing.refAllDecls(@This());
//}
