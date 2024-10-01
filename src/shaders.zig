const file = @import("file_utils.zig");
const cam = @import("camera.zig");
const std = @import("std");

const dvui = @import("dvui");
const ray = dvui.backend.c;

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

pub const RenderTexture = struct {
    raw_render_texture: ray.RenderTexture,
    texture_mode: bool = false,

    pub fn init(width: c_int, height: c_int) @This() {
        return .{ .raw_render_texture = ray.LoadRenderTexture(width, height) };
    }

    pub fn deinit(self: *@This()) void {
        ray.UnloadRenderTexture(self.raw_render_texture);
    }

    pub fn texture(self: *@This()) ray.Texture2D {
        return self.raw_render_texture.texture;
    }

    pub fn updateDimentions(self: *@This()) void {
        if (self.texture().width != ray.GetScreenWidth() or
            self.texture().height != ray.GetScreenHeight())
        {
            std.debug.print("reloading rendertexture\n", .{});
            ray.UnloadRenderTexture(self.raw_render_texture);
            self.raw_render_texture = ray.LoadRenderTexture(ray.GetScreenWidth(), ray.GetScreenHeight());
        }
    }

    pub fn clear(self: *const @This()) void {
        _ = self; // autofix
        ray.ClearBackground(ray.CLEAR); // Clear screen background
    }

    pub fn beginTextureMode(self: *@This()) void {
        std.debug.assert(self.texture_mode == false);
        self.texture_mode = true;
        ray.BeginTextureMode(self.raw_render_texture);
    }

    pub fn endTextureMode(self: *@This()) void {
        std.debug.assert(self.texture_mode == true);
        self.texture_mode = false;
        ray.EndTextureMode();
    }

    pub fn render(self: *@This(), shader: ?FragShader) void {
        if (shader) |sh| {
            sh.beginShaderMode();
        }
        defer if (shader) |sh| {
            sh.endShaderMode();
        };

        // NOTE: Render texture must be y-flipped due to default OpenGL coordinates (left-bottom)
        ray.DrawTextureRec(
            self.texture(),
            .{
                .x = 0,
                .y = 0,
                .width = @floatFromInt(self.texture().width),
                .height = @floatFromInt(-self.texture().height),
            },
            .{ .x = 0, .y = 0 },
            ray.WHITE,
        );
    }
};

pub const FragShader = struct {
    raw_shader: ray.Shader,
    shader_value_locations: std.StringHashMap(c_int),
    enabled: bool = false,

    pub fn init(a: std.mem.Allocator, filepath: [:0]const u8) !FragShader {
        const fullpath = try file.combineAppendSentinel(a, try file.getShaderDirPath(a), filepath);
        defer a.free(fullpath);
        const shader = ray.LoadShader(null, fullpath);
        if (!ray.IsShaderReady(shader)) return error.ShaderFailedToLoad;
        return .{
            .raw_shader = shader,
            .shader_value_locations = std.StringHashMap(c_int).init(a),
        };
    }

    pub fn beginShaderMode(self: *const @This()) void {
        if (self.enabled) {
            ray.BeginShaderMode(self.raw_shader);
        }
    }

    pub fn endShaderMode(self: *const @This()) void {
        //
        if (self.enabled) {
            ray.EndShaderMode();
        }
    }

    pub fn deinit(self: *@This()) void {
        ray.UnloadShader(self.raw_shader);
        self.shader_value_locations.deinit();
    }

    pub fn setShaderValueArray(
        self: *@This(),
        name: [:0]const u8,
        comptime T: type,
        ptr: *const anyopaque,
        count: c_int,
    ) !void {
        const location = try self.shader_value_locations.getOrPut(name);
        if (!location.found_existing) {
            location.value_ptr.* = ray.GetShaderLocation(self.raw_shader, name);
        }
        ray.SetShaderValueV(self.raw_shader, location.value_ptr.*, ptr, getRaylibTypeFlag(T), count);
    }

    pub fn setShaderValue(self: *@This(), name: [:0]const u8, comptime T: type, ptr: *const anyopaque) !void {
        const location = try self.shader_value_locations.getOrPut(name);
        if (!location.found_existing) {
            location.value_ptr.* = ray.GetShaderLocation(self.raw_shader, name);
        }
        ray.SetShaderValue(self.raw_shader, location.value_ptr.*, ptr, getRaylibTypeFlag(T));
    }
};

// pub const ShaderValue = union {
//     float: f32,
//     int: i32,
//     vec2: Vec2,
//     vec3: Vec3,
//     vec4: Vec4,
//     signed_vec2: IVec2,
//     signed_vec3: IVec3,
//     signed_vec4: IVec4,
//     texture: ray.Texture2D,

//     pub const Enum = std.meta.FieldEnum(ShaderValue);

pub fn getRaylibTypeFlag(comptime T: type) c_int {
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

//     pub fn getRaylibTypeFlagEnum(value_type: Enum) c_int {
//         return switch (value_type) {
//             .float => ray.SHADER_UNIFORM_FLOAT,
//             .int => ray.SHADER_UNIFORM_INT,
//             .vec2 => ray.SHADER_UNIFORM_VEC2,
//             .vec3 => ray.SHADER_UNIFORM_VEC3,
//             .vec4 => ray.SHADER_UNIFORM_VEC4,
//             .signed_vec2 => ray.SHADER_UNIFORM_IVEC2,
//             .signed_vec3 => ray.SHADER_UNIFORM_IVEC3,
//             .signed_vec4 => ray.SHADER_UNIFORM_IVEC4,
//             .texture => ray.SHADER_UNIFORM_SAMPLER2D,
//         };
//     }
//    };
//};

//pub fn getRaylibTypeFlag(comptime T: type) i32 {
//    return switch (T) {
//        f32 => ray.SHADER_UNIFORM_FLOAT,
//        i32 => ray.SHADER_UNIFORM_INT,
//        Vec2 => ray.SHADER_UNIFORM_VEC2,
//        Vec3 => ray.SHADER_UNIFORM_VEC3,
//        Vec4 => ray.SHADER_UNIFORM_VEC4,
//        IVec2 => ray.SHADER_UNIFORM_IVEC2,
//        IVec3 => ray.SHADER_UNIFORM_IVEC3,
//        IVec4 => ray.SHADER_UNIFORM_IVEC4,
//        ray.Texture2D => ray.SHADER_UNIFORM_SAMPLER2D,
//        else => @compileError("Invalid Type"),
//    };
//}

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
