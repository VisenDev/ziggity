const debug = @import("debug.zig");
const ray = @cImport({
    @cInclude("raylib.h");
});

///Standard Update options
pub const Update = struct {
    total_time: f32 = 0,
    dt: f32 = 0,
    debugger: *debug.DebugRenderer,

    pub inline fn dtInMs(self: Update) f32 {
        return self.dt * 1000.0;
    }
    pub fn update(self: *Update) void {
        self.dt = ray.GetFrameTime();
        self.total_time += self.dt;
    }
};

/////Standard Rendering Options
//pub const Render = struct {
//    scale: f32,
//    grid_spacing: f32,
//    zoom: f32,
//
//    pub fn getScreenPosition(self: *const @This(), vec: ray.Vector2) ray.Vector2 {
//        return ray.Vector2{ .x = vec.x * self.grid_spacing, .y = vec.y * self.grid_spacing };
//    }
//};
