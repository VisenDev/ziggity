const ray = @cImport({
    @cInclude("raylib.h");
});
const level = @import("../level.zig");
const entity = @import("../components.zig");
const std = @import("std");

pub fn normalize(self: ray.Vector2) ray.Vector2 {
    const magnitude = @sqrt(self.x * self.x + self.y * self.y);
    return ray.Vector2{
        .x = self.x / magnitude,
        .y = self.y / magnitude,
    };
}

pub const name = "position";
pos: ray.Vector2 = ray.Vector2{ .x = 0, .y = 0 },
vel: ray.Vector2 = ray.Vector2{ .x = 0, .y = 0 },
//acc: ray.Vector2 = ray.Vector2{ .x = 1, .y = 1 },
acceleration: f32 = 1,
friction: f32 = 0.30,

pub fn update(self: *@This(), e: *const entity.EntityState, ent: entity.UpdateOptions, opt: level.UpdateOptions) void {
    _ = ent;
    _ = e;
    self.pos.x += self.vel.x * opt.dt; // * dt;
    self.pos.y += self.vel.y * opt.dt; // * dt;

    self.vel.x *= self.friction;
    self.vel.y *= self.friction;
}

pub fn handle(self: *@This(), e: *entity.EntityState, event: *entity.Event) void {
    _ = e;
    if (std.mem.eql(u8, event.name, "move")) {
        self.moveTowards(event.location);
    }

    //if (std.mem.eql(u8, event.name, "position_request")) {
    //    var new_event = entity.Event(.{.name = "position_broadcast", .location = self.pos});
    //    e.notify(event.id, &new_event);
    //}
}

pub fn moveTowards(self: *@This(), destination: ray.Vector2) void {
    var direction = ray.Vector2{
        .x = destination.x - self.pos.x,
        .y = destination.y - self.pos.y,
    };
    direction = normalize(direction);
    self.moveInDirection(direction);
}

pub fn moveInDirection(self: *@This(), direction: ray.Vector2) void {
    self.vel.x += direction.x * self.acceleration;
    self.vel.y += direction.y * self.acceleration;
}
