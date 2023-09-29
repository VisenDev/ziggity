const ray = @cImport({
    @cInclude("raylib.h");
});

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
friction: f32 = 0.50,

pub fn update(self: *@This(), dt: f32) void {
    self.pos.x += self.vel.x * dt; // * dt;
    self.pos.y += self.vel.y * dt; // * dt;

    self.vel.x *= self.friction;
    self.vel.y *= self.friction;
}

pub fn moveTowards(self: *@This(), destination: ray.Vector2) void {
    var direction = ray.Vector2{
        .x = destination.x - self.pos.x,
        .y = destination.y - self.pos.y,
    };
    direction = normalize(direction);
    self.moveInDirection(direction);

    //self.vel.x += direction.x * self.acceleration;
    //self.vel.y += direction.y * self.acceleration;
}

pub fn moveInDirection(self: *@This(), direction: ray.Vector2) void {
    self.vel.x += direction.x * self.acceleration;
    self.vel.y += direction.y * self.acceleration;
}
