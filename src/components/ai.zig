//===========INCLUDES===========
const ray = @cImport({
    @cInclude("raylib.h");
});
const entity = @import("../components.zig");

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

pub fn update(self: *@This(), e: *const entity.EntityState, self_id: usize, dt: f32) void {
    const self_pos = e.getPosition(self_id).?;
    const target_pos = e.getPosition(self.target_id.?).?;

    //update cooldown
    if (self.cooldown_remaining > 0) self.cooldown_remaining -= dt;

    //distance from self to the target
    const target_distance = distance(self_pos, target_pos);

    //update the action
    switch (self.action) {
        .wander => {
            if (target_distance < self.view_range) {
                self.action = .pursue;
            } else {
                var position = (e.systems.position.get(self_id) catch return).?;
                position.moveTowards(self.wander_destination);
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
                var position = (e.systems.position.get(self_id) catch return).?;
                position.moveTowards(target_pos);
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
