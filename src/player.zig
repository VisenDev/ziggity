const entity = @import("components.zig");
const file = @import("file_utils.zig");
const config = @import("config.zig");

pub fn updatePlayer(player_id: usize, state: *const entity.EntityState, key: *const config.KeyBindings, dt: f32) !void {
    if (try state.systems.position.indexEmpty(player_id)) {
        return error.invalid_player_index;
    }

    const speed = 200.0 * dt;

    var player = (try state.systems.position.get(player_id)).?;

    if (key.player_up.pressed()) {
        player.pos.y -= speed;
    }

    if (key.player_down.pressed()) {
        player.pos.y += speed;
    }

    if (key.player_left.pressed()) {
        player.pos.x -= speed;
    }

    if (key.player_right.pressed()) {
        player.pos.x += speed;
    }
}
