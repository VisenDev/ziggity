const ray = @cImport({
    @cInclude("raylib.h");
});

///Standard Update options
pub const Update = struct {
    //delta time is in milliseconds;
    dt: f32,
    pub inline fn dtInMs(self: Update) f32 {
        return self.dt * 1000.0;
    }
};

///Standard Rendering Options
pub const Render = struct {
    scale: f32,
    grid_spacing: f32,
    zoom: f32,

    pub fn getScreenPosition(self: *const @This(), vec: ray.Vector2) ray.Vector2 {
        return ray.Vector2{ .x = vec.x * self.grid_spacing, .y = vec.y * self.grid_spacing };
    }
};
