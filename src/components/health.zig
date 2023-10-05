const level = @import("../level.zig");
const entity = @import("../components.zig");

pub const name = "health";
hp: f64 = 10,
max_hp: f64 = 10,
health_loss_rate: f64 = 0,
is_dead: bool = false,

    
pub fn update(self: *@This(), e: *const entity.EntityState, ent: entity.UpdateOptions, opt: level.UpdateOptions) void {
    _ = ent;
    _ = e;
    self.hp -= self.health_loss_rate * opt.dt;

    if (self.hp < 0) {
        self.is_dead = true;
    }
}

pub fn takeDamage(self: *@This(), damage: f32) void {
    self.*.hp -= damage;
    if (self.*.hp <= 0) {
        self.*.is_dead = true;
    }
}
