const entity = @import("components.zig");
const file = @import("file_utils.zig");
const config = @import("config.zig");
const level = @import("level.zig");

const ray = @cImport({
    @cInclude("raylib.h");
});

pub fn updatePlayer(player_id: usize, state: *const entity.EntityState, opt: level.UpdateOptions) !void {
    if (try state.systems.position.indexEmpty(player_id)) {
        return error.invalid_player_index;
    }

    var direction = ray.Vector2{ .x = 0, .y = 0 };

    if (opt.keys.player_up.pressed()) {
        direction.y -= 1;
    }

    if (opt.keys.player_down.pressed()) {
        direction.y += 1;
    }

    if (opt.keys.player_left.pressed()) {
        direction.x -= 1;
    }

    if (opt.keys.player_right.pressed()) {
        direction.x += 1;
    }

    state.systems.position.get(player_id).?.acceleration = 10;
    state.systems.position.get(player_id).?.moveInDirection(direction);
}
