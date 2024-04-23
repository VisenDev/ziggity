const ray = @cImport({
    @cInclude("raylib.h");
});
const std = @import("std");
const shader = @import("shaders.zig");
const cam = @import("camera.zig");

pub const Light = extern struct {
    color: shader.Vec4 = .{},
    radius: f32 = 0,
    position: shader.Vec2 = .{},
};

pub const LightShader = struct {
    pub const max_num_lights = 64;

    shader: ray.Shader,
    lights: std.MultiArrayList(Light),
    locations: std.StringHashMap(i32),
    num_active_lights: i32,

    pub fn init(a: std.mem.Allocator) !LightShader {
        const my_shader = try shader.loadFragmentShader(a, "light.fs");

        var lights = std.MultiArrayList(Light){};
        try lights.ensureTotalCapacity(a, max_num_lights);
        for (0..max_num_lights) |_| {
            try lights.append(a, .{});
        }

        var locations = std.StringHashMap(i32).init(a);
        try locations.put("num_active_lights", ray.GetShaderLocation(my_shader, "num_active_lights"));
        try locations.put("screen_height", ray.GetShaderLocation(my_shader, "screen_height"));
        try locations.put("screen_width", ray.GetShaderLocation(my_shader, "screen_width"));

        inline for (std.meta.fields(Light)) |field| {
            try locations.put(field.name, ray.GetShaderLocation(my_shader, field.name));
        }

        return .{
            .shader = my_shader,
            .lights = lights,
            .num_active_lights = 0,
            .locations = locations,
        };
    }

    pub fn deinit(self: *@This(), a: std.mem.Allocator) void {
        self.lights.deinit(a);
        ray.UnloadShader(self.shader);
        self.locations.deinit();
    }

    pub fn addLight(self: *@This(), a: std.mem.Allocator, light: Light, camera: ray.Camera2D) !void {
        _ = a;
        //TODO check if light will be visible before rendering
        //TODO convert world coordinates to screen coordinates for the shader
        _ = camera;
        if (self.num_active_lights == max_num_lights) return error.OutOfCapacity;

        self.lights.set(@intCast(self.num_active_lights), light);
        self.num_active_lights += 1;
    }

    pub fn render(self: *@This()) void {
        const num_loc = self.locations.get("num_active_lights").?;
        ray.SetShaderValue(self.shader, num_loc, &self.num_active_lights, shader.getRaylibTypeFlag(i32));

        const width_loc = self.locations.get("screen_width").?;
        const width = ray.GetScreenWidth();
        ray.SetShaderValue(self.shader, width_loc, &width, shader.getRaylibTypeFlag(i32));

        const height_loc = self.locations.get("screen_height").?;
        const height = ray.GetScreenHeight();
        ray.SetShaderValue(self.shader, height_loc, &height, shader.getRaylibTypeFlag(i32));

        inline for (std.meta.fields(Light)) |field| {
            const loc = self.locations.get(field.name).?;
            const field_enum = @field(std.MultiArrayList(Light).Field, field.name);
            const data = self.lights.items(field_enum);
            ray.SetShaderValueV(self.shader, loc, data.ptr, shader.getRaylibTypeFlag(field.type), self.num_active_lights);
        }

        self.num_active_lights = 0;
    }
};
