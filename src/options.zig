const debug = @import("debug.zig");
const std = @import("std");
const ray = @cImport({
    @cInclude("raylib.h");
});

///Standard Update options
pub const Update = struct {
    ///time since game opening
    total_time_ms: f32 = 0,
    dt: f32 = 0,
    debugger: *debug.DebugRenderer = undefined,
    //start_timestamp: i32 = 0,
    last_frame_timestamp: i64 = 0,

    pub fn init(debugger: *debug.DebugRenderer) @This() {
        var self = @This(){};

        self.debugger = debugger;
        self.last_frame_timestamp = std.time.microTimestamp();
        return self;
    }

    pub inline fn dtInMs(self: Update) f32 {
        return self.dt * 1000.0;
    }
    pub fn update(self: *Update) void {
        const timestamp = std.time.microTimestamp();
        const time_passed: f32 = @floatFromInt(timestamp - self.last_frame_timestamp);
        const dt = time_passed / 1_000_000;
        self.dt = dt;
        self.last_frame_timestamp = timestamp;
        //std.debug.print("dt: {d}\n", .{dt});

        //self.dt = ray.GetFrameTime();
        self.total_time_ms += self.dtInMs();
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
