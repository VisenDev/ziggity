const std = @import("std");
const camera = @import("camera.zig");
const Lua = @import("ziglua").Lua;
const file = @import("file_utils.zig");
const options = @import("options.zig");
const SparseSet = @import("sparse_set.zig").SparseSet;
const ray = @cImport({
    @cInclude("raylib.h");
});

fn tof32(input: anytype) f32 {
    return @floatFromInt(input);
}

pub const AnimationFrame = struct {
    subrect: ray.Rectangle,
    milliseconds: f32 = 250,
};

pub const Animation = struct {
    texture: ?ray.Texture2D = null,
    filepath: []const u8,
    name: []const u8,
    loop: bool = true,
    rotation_speed: f32 = 0, //scalar to be multiplied by dt when rotating
    origin: ray.Vector2 = .{ .x = 0, .y = 0 },
    render_style: enum { pixel_perfect, scaled } = .pixel_perfect,
    frames: []const AnimationFrame = &.{},

    pub inline fn length(self: *const @This()) usize {
        return self.frames.len;
    }

    pub inline fn nextFrame(self: *const @This(), current_frame: usize) usize {
        return (current_frame + 1) % self.length();
    }
};

pub const AnimationPlayer = struct {
    animation_name: []const u8,
    current_frame: usize = 0,
    remaining_frame_time: f32 = 0,
    rotation: f32 = 0,
    tint: ray.Color = ray.WHITE,
    disabled: bool = false,

    //renders the animation
    pub fn render(self: *const @This(), state: *const AnimationState, position: ray.Vector2) void {
        if (self.disabled) return;

        const animation = state.animations.get(self.animation_name) orelse {
            std.log.warn("missing animation: {s}\n", .{self.animation_name});
            return;
        };

        const texture = if (animation.texture != null) animation.texture.? else @panic("missing texture");

        const subrect = if (animation.frames.len > 0)
            animation.frames[self.current_frame].subrect
        else
            ray.Rectangle{
                .x = 0,
                .y = 0,
                .width = @floatFromInt(texture.width),
                .height = @floatFromInt(texture.height),
            };
        const render_rect = ray.Rectangle{
            .x = position.x,
            .y = position.y,
            .width = camera.render_resolution + 0.1,
            .height = camera.render_resolution + 0.1,
        };
        ray.DrawTexturePro(texture, subrect, render_rect, animation.origin, self.rotation, self.tint);
    }

    //updates animation frame and rotation
    pub fn update(self: *@This(), state: *const AnimationState, opt: options.Update) void {
        const animation = state.animations.get(self.animation_name) orelse {
            std.log.warn("missing animation: {s}\n", .{self.animation_name});
            return;
        };
        if (animation.frames.len == 0) return;

        self.remaining_frame_time -= opt.dtInMs();

        //TODO fix rotation_speed
        self.rotation += animation.rotation_speed * opt.dt;

        if (self.remaining_frame_time <= 0) {
            if (animation.loop == false and self.current_frame == animation.frames.len - 1) {
                self.disabled = true;
                //std.debug.print("animation is disabled: {s}", .{self.animation_name});
            }

            self.current_frame = animation.nextFrame(self.current_frame);
            self.remaining_frame_time = animation.frames[self.current_frame].milliseconds;
        }
    }
};

pub const AnimationState = struct {
    animations: std.StringHashMap(Animation),
    textures: std.StringHashMap(ray.Texture2D),

    pub fn deinit(self: *@This()) void {
        _ = self;

        //TODO implement
    }

    pub fn init(a: std.mem.Allocator, lua: *Lua) !@This() {
        var self = .{
            .animations = std.StringHashMap(Animation).init(a),
            .textures = std.StringHashMap(ray.Texture2D).init(a),
        };
        errdefer self.animations.deinit();
        errdefer self.textures.deinit();

        const config = try file.readConfig([]Animation, lua, .animations);
        defer config.deinit();

        for (config.value) |animation| {
            std.debug.print("Preloaded-Animation config: {s}\n", .{animation.name});
        }

        for (config.value) |*animation| {
            std.log.info("Attempting to load Animation: {s}\n", .{animation.name});
            if (!self.textures.contains(animation.filepath)) {
                const path = try file.combineAppendSentinel(a, try file.getImageDirPath(a), animation.filepath);
                defer a.free(path);

                const image = ray.LoadImage(path.ptr);
                defer ray.UnloadImage(image);

                const texture = ray.LoadTextureFromImage(image);
                if (!ray.IsTextureReady(texture)) {
                    std.debug.print("path: {*}\n", .{path.ptr});
                    @panic("failed to load texture");
                }
                try self.textures.put(animation.filepath, texture);
            }
            animation.texture = self.textures.get(animation.filepath).?;

            std.log.info("Loaded Animation: {s}\n", .{animation.name});
            try self.animations.put(animation.name, animation.*);
        }

        return self;
    }
};

test "animation_json" {
    const string =
        \\[
        \\{
        \\   "frames": [
        \\   {
        \\      "subrect": {"x": 0, "y": 0, "width": 4, "height": 4}, 
        \\         "milliseconds": 250                                   
        \\   }
        \\   ],
        \\   "name": "particle",
        \\   "rotation_speed": 0,
        \\   "filepath": "particle.png",
        \\   "origin": {"x": 8, "y": 8} 
        \\},
        \\{
        \\   "frames": [
        \\   {
        \\      "subrect": {"x": 0, "y": 0, "width": 16, "height": 32},
        \\      "milliseconds": 250                                 
        \\   }
        \\   ],
        \\   "name": "player",
        \\   "rotation_speed": 0,
        \\   "filepath": "player.png",
        \\   "origin": {"x": 0, "y": 0} 
        \\},
        \\{
        \\   "frames": [
        \\   {
        \\      "subrect": {"x": 0, "y": 0, "width": 8, "height": 8},
        \\      "milliseconds": 250                                
        \\   }
        \\   ],
        \\   "name": "slime",
        \\   "rotation_speed": 1,
        \\   "filepath": "slime.png",
        \\   "origin": {"x": 4, "y": 4} 
        \\}
        \\]
    ;

    const parsed = try std.json.parseFromSlice([]Animation, std.testing.allocator, string, .{});
    defer parsed.deinit();
}
