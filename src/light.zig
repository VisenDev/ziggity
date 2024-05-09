const ray = @cImport({
    @cInclude("raylib.h");
});
const anime = @import("animation.zig");
const std = @import("std");
const options = @import("options.zig");
const shader = @import("shaders.zig");
const ecs = @import("ecs.zig");
const Component = @import("components.zig");

pub const LightComponent = struct {
    color: shader.Vec4 = .{ .x = 1.0, .y = 1.0, .z = 1.0, .a = 1.0 },
    radius: f32 = 0.1,
};

pub const ShaderLight = extern struct {
    color: shader.Vec4 = .{},
    radius: f32 = 0.0,
    position: shader.Vec2 = .{},
};

pub const LightShader = struct {
    pub const max_num_lights = 1024;

    shader: ray.Shader,
    lights: std.MultiArrayList(ShaderLight),
    locations: std.StringHashMap(i32),
    num_active_lights: i32,

    pub fn init(a: std.mem.Allocator) !LightShader {
        const my_shader = try shader.loadFragmentShader(a, "light.fs");

        var lights = std.MultiArrayList(ShaderLight){};
        try lights.ensureTotalCapacity(a, max_num_lights);
        for (0..max_num_lights) |_| {
            try lights.append(a, .{});
        }

        var locations = std.StringHashMap(i32).init(a);
        try locations.put("num_active_lights", ray.GetShaderLocation(my_shader, "num_active_lights"));
        try locations.put("screen_height", ray.GetShaderLocation(my_shader, "screen_height"));
        try locations.put("screen_width", ray.GetShaderLocation(my_shader, "screen_width"));

        inline for (std.meta.fields(ShaderLight)) |field| {
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

    pub fn addLightToRender(self: *@This(), light: LightComponent, tile_position: ray.Vector2) !void {
        if (self.num_active_lights == max_num_lights) return error.OutOfCapacity;

        const shader_light = ShaderLight{
            .color = light.color,
            .radius = light.radius,
            .position = .{ .x = tile_position.x, .y = tile_position.y }, //shader.convertTileToOpenGL(tile_position, self.camera.*),
        };
        self.lights.set(@intCast(self.num_active_lights), shader_light);
        self.num_active_lights += 1;
    }

    pub fn render(self: *@This(), animation_state: *const anime.AnimationState) void {
        const num_loc = self.locations.get("num_active_lights").?;
        ray.SetShaderValue(self.shader, num_loc, &self.num_active_lights, shader.getRaylibTypeFlag(i32));

        const width_loc = self.locations.get("screen_width").?;
        const width = ray.GetScreenWidth();
        ray.SetShaderValue(self.shader, width_loc, &width, shader.getRaylibTypeFlag(i32));

        const height_loc = self.locations.get("screen_height").?;
        const height = ray.GetScreenHeight();
        ray.SetShaderValue(self.shader, height_loc, &height, shader.getRaylibTypeFlag(i32));

        //convert tile coordinates to OpenGl Coordinates
        for (self.lights.items(.position)) |*pos| {
            pos.* = animation_state.TileToOpenGl(pos.*);
        }

        //scale radius using zoom
        for (self.lights.items(.radius)) |*rad| {
            rad.* *= animation_state.camera.zoom;
        }

        inline for (std.meta.fields(ShaderLight)) |field| {
            const loc = self.locations.get(field.name).?;
            const field_enum = @field(std.MultiArrayList(ShaderLight).Field, field.name);
            const data = self.lights.items(field_enum);
            ray.SetShaderValueV(self.shader, loc, data.ptr, shader.getRaylibTypeFlag(field.type), self.num_active_lights);
        }

        self.num_active_lights = 0;
    }
};

pub fn updateLightingSystem(
    self: *ecs.ECS,
    a: std.mem.Allocator,
    light_shader: *LightShader,
    opt: options.Update,
) !void {
    const systems = [_]type{ Component.Light, Component.Physics };
    const set = self.getSystemDomain(a, &systems);

    opt.debugger.addText("Num Lights: {}", .{set.len});

    for (set) |member| {
        const light = self.get(Component.Light, member);
        const physics = self.get(Component.Physics, member);

        try light_shader.addLightToRender(light.*, physics.pos);
    }
}
