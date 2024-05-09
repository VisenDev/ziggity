const file = @import("file_utils.zig");
const cam = @import("camera.zig");
const std = @import("std");
const ray = @cImport({
    @cInclude("raylib.h");
});

pub const Vec2 = ray.Vector2; //extern struct { x: f32 = 0, y: f32 = 0 };
pub const Vec3 = extern struct { x: f32 = 0, y: f32 = 0, z: f32 = 0 };
pub const Vec4 = extern struct { x: f32 = 0, y: f32 = 0, z: f32 = 0, a: f32 = 0 };
pub const IVec2 = extern struct { x: i32 = 0, y: i32 = 0 };
pub const IVec3 = extern struct { x: i32 = 0, y: i32 = 0, z: i32 = 0 };
pub const IVec4 = extern struct { x: i32 = 0, y: i32 = 0, z: i32 = 0, a: i32 = 0 };

pub fn loadFragmentShader(a: std.mem.Allocator, fragment_shader_path: [:0]const u8) !ray.Shader {
    const fullpath = try file.combineAppendSentinel(a, try file.getShaderDirPath(a), fragment_shader_path);
    defer a.free(fullpath);
    const shader = ray.LoadShader(null, fullpath);
    if (!ray.IsShaderReady(shader)) return error.ShaderFailedToLoad;
    return shader;
}

pub fn getRaylibTypeFlag(comptime T: type) i32 {
    return switch (T) {
        f32 => ray.SHADER_UNIFORM_FLOAT,
        i32 => ray.SHADER_UNIFORM_INT,
        Vec2 => ray.SHADER_UNIFORM_VEC2,
        Vec3 => ray.SHADER_UNIFORM_VEC3,
        Vec4 => ray.SHADER_UNIFORM_VEC4,
        IVec2 => ray.SHADER_UNIFORM_IVEC2,
        IVec3 => ray.SHADER_UNIFORM_IVEC3,
        IVec4 => ray.SHADER_UNIFORM_IVEC4,
        ray.Texture2D => ray.SHADER_UNIFORM_SAMPLER2D,
        else => @compileError("Invalid Type"),
    };
}

//pub fn convertTileToOpenGL(pos: ray.Vector2, camera: ray.Camera2D) Vec2 {
//    const screenPos = cam.tileToScreen(pos, camera);
//
//    return Vec2{
//        .x = ((screenPos.x / cam.screenWidth())),
//        .y = (1 - (screenPos.y / cam.screenHeight())),
//    };
//}

//pub const ShaderValue = struct {
//    pub const Float = f32;
//    pub const Int = i32;
//    pub const Vec2 = extern struct { x: f32, y: f32 };
//    pub const Vec3 = extern struct { x: f32, y: f32, z: f32 };
//    pub const Vec4 = extern struct { x: f32, y: f32, z: f32, a: f32 };
//    pub const IVec2 = extern struct { x: i32, y: i32 };
//    pub const IVec3 = extern struct { x: i32, y: i32, z: i32 };
//    pub const IVec4 = extern struct { x: i32, y: i32, z: i32, a: i32 };
//    pub const Texture = ray.Texture2D;
//};
//
//export var buffer: [128]u8 = [1]u8{0} ** 128;
//
//pub fn setShaderValue(shader: ray.Shader, name: [:0]const u8, value: anytype) !void {
//    const loc = ray.GetShaderLocation(shader, name);
//    std.mem.copyForwards(u8, &buffer, &std.mem.toBytes(value));
//
//    switch (@TypeOf(value)) {
//        ShaderValue.Float => ray.SetShaderValue(shader, loc, &buffer, ray.SHADER_UNIFORM_FLOAT),
//        ShaderValue.Int => ray.SetShaderValue(shader, loc, &buffer, ray.SHADER_UNIFORM_INT),
//        ShaderValue.Vec2 => ray.SetShaderValue(shader, loc, &buffer, ray.SHADER_UNIFORM_VEC2),
//        ShaderValue.Vec3 => ray.SetShaderValue(shader, loc, &buffer, ray.SHADER_UNIFORM_VEC3),
//        ShaderValue.Vec4 => ray.SetShaderValue(shader, loc, &buffer, ray.SHADER_UNIFORM_VEC4),
//        ShaderValue.IVec2 => ray.SetShaderValue(shader, loc, &buffer, ray.SHADER_UNIFORM_IVEC2),
//        ShaderValue.IVec3 => ray.SetShaderValue(shader, loc, &buffer, ray.SHADER_UNIFORM_IVEC3),
//        ShaderValue.IVec4 => ray.SetShaderValue(shader, loc, &buffer, ray.SHADER_UNIFORM_IVEC4),
//        ShaderValue.Texture => ray.SetShaderValue(shader, loc, &buffer, ray.SHADER_UNIFORM_SAMPLER2D),
//        else => @compileError("Invalid Type"),
//    }
//}
