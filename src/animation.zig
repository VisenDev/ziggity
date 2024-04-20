const std = @import("std");
const tile = @import("tiles.zig");
const Component = @import("components.zig");
const ecs = @import("ecs.zig");
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
    //rotation_speed: f32 = 0, //scalar to be multiplied by dt when rotating
    origin: ray.Vector2 = .{ .x = 0, .y = 0 },
    //render_style: enum { pixel_perfect, scaled } = .pixel_perfect,
    frames: []const AnimationFrame = &.{},

    pub inline fn length(self: *const @This()) usize {
        return self.frames.len;
    }

    pub inline fn nextFrame(self: *const @This(), current_frame: usize) usize {
        return (current_frame + 1) % self.length();
    }
};

pub const RenderOptions = struct {
    rotation: f32 = 0,
    tint: ray.Color = ray.WHITE,
    flipped: bool = false,
    render_style: enum { scaled_to_grid, actual } = .scaled_to_grid,
    vertical_scale: f32 = 1.0,
    horizontal_scale: f32 = 1.0,
};

///flips a subrect
fn flipSelection(r: ray.Rectangle) ray.Rectangle {
    return .{
        .x = r.x,
        .y = r.y,
        .width = -r.width,
        .height = r.height,
    };
}

pub const AnimationPlayer = struct {
    animation_name: []const u8,
    current_frame: usize = 0,
    remaining_frame_time: f32 = 0,
    disabled: bool = false,

    //renders the animation
    pub fn render(self: *const @This(), state: *const AnimationState, position: ray.Vector2, opt: RenderOptions) void {
        if (self.disabled) return;

        const animation = state.animations.get(self.animation_name) orelse {
            std.log.warn("missing animation: {s}\n", .{self.animation_name});
            return;
        };

        const texture =
            if (animation.texture != null)
            animation.texture.?
        else
            @panic("missing texture, this should never happen");

        const unflipped_subrect =
            if (animation.frames.len > 0)
            animation.frames[self.current_frame].subrect
        else
            ray.Rectangle{
                .x = 0,
                .y = 0,
                .width = @floatFromInt(texture.width),
                .height = @floatFromInt(texture.height),
            };

        const subrect = if (opt.flipped) flipSelection(unflipped_subrect) else unflipped_subrect;

        const render_rect =
            if (opt.render_style == .scaled_to_grid)
            ray.Rectangle{
                .x = position.x,
                .y = position.y,
                .width = camera.render_resolution + 0.1,
                .height = camera.render_resolution + 0.1,
            }
        else
            ray.Rectangle{
                .x = position.x,
                .y = position.y,
                .width = @floatFromInt(texture.width),
                .height = @floatFromInt(camera.render_resolution),
            };

        ray.DrawTexturePro(texture, subrect, render_rect, animation.origin, opt.rotation, opt.tint);
    }

    //updates animation frame and rotation
    pub fn update(self: *@This(), state: *const AnimationState, opt: options.Update) void {
        const animation = state.animations.get(self.animation_name) orelse {
            std.log.warn("missing animation: {s}\n", .{self.animation_name});
            return;
        };
        if (animation.frames.len == 0) return;

        self.remaining_frame_time -= opt.dtInMs();

        if (self.remaining_frame_time <= 0) {
            if (animation.loop == false and self.current_frame == animation.frames.len - 1) {
                self.disabled = true;
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

        for (config.value) |*animation| {
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

            std.log.info("Loaded Animation: {s}", .{animation.name});
            try self.animations.put(animation.name, animation.*);
        }

        return self;
    }
};

//===============RENDERING================

pub inline fn scaleVector(a: ray.Vector2, scalar: anytype) ray.Vector2 {
    if (@TypeOf(scalar) == f32)
        return .{ .x = a.x * scalar, .y = a.y * scalar };

    return .{ .x = a.x * tof32(scalar), .y = a.y * tof32(scalar) };
}

pub inline fn scaleRectangle(a: ray.Rectangle, scalar: anytype) ray.Rectangle {
    if (@TypeOf(scalar) == f32)
        return .{ .x = a.x * scalar, .y = a.y * scalar, .width = a.width * scalar, .height = a.height * scalar };

    const floated = tof32(scalar);
    return .{ .x = a.x * floated, .y = a.y * floated, .width = a.width * floated, .height = a.height * floated };
}

pub fn renderSprites(
    self: *ecs.ECS,
    a: std.mem.Allocator,
    animation_state: *const AnimationState,
) void {
    const systems = [_]type{ Component.Physics, Component.Sprite };
    const set = self.getSystemDomain(a, &systems);

    inline for (@typeInfo(Component.Sprite.ZLevels).Enum.fields) |current_z_level_decl| {
        for (set) |member| {
            const current_z_level = @field(Component.Sprite.ZLevels, current_z_level_decl.name);
            const sprite = self.get(Component.Sprite, member);
            const physics = self.get(Component.Physics, member);

            if (sprite.disabled) continue;
            if (sprite.z_level != current_z_level) continue;

            const opt = RenderOptions{
                .flipped = physics.vel.x > 0,
            };

            sprite.animation_player.render(animation_state, scaleVector(physics.pos, camera.render_resolution), opt);
        }
    }
}
