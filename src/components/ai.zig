//===========INCLUDES===========
const ray = @cImport({
    @cInclude("raylib.h");
});
const entity = @import("../components.zig");
const level = @import("../level.zig");

fn distance(a: ray.Vector2, b: ray.Vector2) f32 {
    const dx = a.x - b.x;
    const dy = a.y - b.y;

    return @sqrt(dx * dx + dy * dy);
}

//=======IMPLEMENTATION=========
pub const name = "hostile_ai";

spawn_point: ?ray.Vector2 = null,
wander_destination: ray.Vector2 = .{ .x = 0, .y = 0 },
target_id: ?usize = null,
view_range: f32 = 25,
max_attack_range: f32 = 8.0,
min_attack_range: f32 = 4.0,
cooldown_remaining: f32 = 0,
action: enum { pursue, attack, move, wander, patrol } = .wander,

pub fn update(self: *@This(), e: *const entity.EntityState, info: entity.UpdateOptions, opt: level.UpdateOptions) void {
    //update cooldown
    if (self.cooldown_remaining > 0) self.cooldown_remaining -= opt.dt;

    //update the action
    switch (self.action) {
        .wander => {
            if(self.target_id) |target_id| {
                
                const self_pos = e.getPosition(info.id).?;
                const target_pos = e.getPosition(target_id).?;
                const target_distance = distance(self_pos, target_pos);
                
                if (target_distance < self.view_range) {
                    self.action = .pursue;
                }

            } else {
                
                var query = entity.Event{ .id = info.id, .name = "target_query"};
                e.notify(&query);
                
                var event = entity.Event{ .id = info.id, .name = "move", .location = self.wander_destination };
                e.notify(&event);
            }
        },
        .pursue => {
            if (target_distance < self.max_attack_range and target_distance > self.min_attack_range and self.cooldown_remaining <= 0) {

                //try to attack the target
                self.action = .attack;
            } else if (target_distance > self.view_range) {

                //lose interest
                self.action = .wander;
            } else if (target_distance > self.min_attack_range) {
                //move towards the target
                //var position = e.systems.position.get(self_id).?;
                //_ = position;
                var event = entity.Event{ .id = self_id, .name = "move", .location = target_pos };
                e.notify(&event);
            }
        },
        .attack => {
            if (target_distance < self.max_attack_range and target_distance > self.min_attack_range and self.cooldown_remaining <= 0) {
                self.cooldown_remaining = 1000;
                self.action = .pursue;
                //TODO IMPLEMENTATION
            }
        },
        else => {},
    }
}
