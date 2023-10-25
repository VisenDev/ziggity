const std = @import("std");
const file = @import("file_utils.zig");
const options = @import("options.zig");
const SparseSet = @import("sparse_set.zig").SparseSet;
const ray = @cImport({
    @cInclude("raylib.h");
});

pub const AnimationFrame = struct {
    subrect: ray.Rectangle,
    milliseconds: f32 = 250,
};

pub const Animation = struct {
    texture: ?ray.Texture2D = null,
    filepath: []const u8,
    name: []const u8,
    rotation_speed: f32 = 0, //scalar to be multiplied by dt when rotating
    origin: ray.Vector2 = .{ .x = 0, .y = 0 },
    frames: []const AnimationFrame,

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

    //renders the animation
    pub fn render(self: *@This(), state: *const AnimationState, position: ray.Rectangle) void {
        const animation = state.animations.get(self.animation_name).?;
        const frame = animation.frames[self.current_frame];
        ray.DrawTexturePro(animation.texture.?, frame.subrect, position, animation.origin, self.rotation, self.tint);
    }

    //updates animation frame and rotation
    pub fn update(self: *@This(), state: *const AnimationState, opt: options.Update) void {
        const animation = state.animations.get(self.animation_name).?;
        self.remaining_frame_time -= opt.dt;
        self.rotation += animation.rotation_speed * opt.dt;

        if (self.remaining_frame_time <= 0) {
            self.current_frame = animation.nextFrame(self.current_frame);
            self.remaining_frame_time = animation.frames[self.current_frame].milliseconds;
        }
    }
};

pub const AnimationState = struct {
    animations: std.StringHashMap(Animation),

    pub fn init(a: std.mem.Allocator) !@This() {
        const animations_json = try file.readConfig([]Animation, a, "animations.json");
        var animations = std.StringHashMap(Animation).init(a);

        for (animations_json.value) |*animation| {
            const path = try file.combine(a, try file.getImageDirPath(a), animation.filepath);
            defer a.free(path);

            const image = ray.LoadImage(path.ptr);
            defer ray.UnloadImage(image);

            const texture = ray.LoadTextureFromImage(image);
            animation.texture = texture;

            try animations.put(animation.name, animation.*);
        }

        return .{ .animations = animations };
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
