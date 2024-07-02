const std = @import("std");
const shader = @import("shaders.zig");
const key = @import("keybindings.zig");
const level = @import("level.zig");
const cam = @import("camera.zig");
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

pub fn screenWidth() f32 {
    return @floatFromInt(ray.GetScreenWidth());
}

pub fn screenHeight() f32 {
    return @floatFromInt(ray.GetScreenHeight());
}

pub const SpriteComponent = struct {

    //z level constants
    pub const ZLevels = enum { background, middleground, foreground };
    animation_player: AnimationPlayer = .{ .animation_name = "default" },
    z_level: ZLevels = .middleground,
    disabled: bool = false,
    styling: struct {
        bob: ?struct {
            cycle_time_ms: f32 = 500,
            distance: f32 = 0.1,
        } = null,
        lean: ?struct {
            max_angle_radians: f32 = std.math.pi,
            resistance: f32 = 5,
        } = null,
        scale: ?struct {
            current: f32 = 1.0,
            rate_of_change: f32 = 0.99,
            min_scale: f32 = 0,
        } = null,
    } = .{},
    creation_time: ?f32 = null,
};

pub const AnimationFrame = struct {
    subrect: ray.Rectangle,
    milliseconds: f32 = 250,
};

pub const Animation = struct {
    texture: ?ray.Texture2D = null,
    filepath: []const u8,
    name: []const u8,
    loop: bool = true,
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
    rotation_radians: f32 = 0,
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
    pub fn render(self: *const @This(), state: *const AnimationState, tilemap_position: ray.Vector2, opt: RenderOptions) void {
        if (self.disabled) return;

        const animation = state.animations.get(self.animation_name) orelse {
            std.log.warn("missing animation: {s}\n", .{self.animation_name});
            return;
        };

        const texture = if (animation.texture != null)
            animation.texture.?
        else
            @panic("missing texture, this should never happen");

        const unflipped_subrect = if (animation.frames.len > 0)
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
            ray.Rectangle{
            .x = tilemap_position.x * state.tilemap_resolution,
            .y = tilemap_position.y * state.tilemap_resolution,
            .width = (unflipped_subrect.width * opt.horizontal_scale) + 0.001,
            .height = (unflipped_subrect.height * opt.vertical_scale) + 0.001,
        };

        ray.DrawTexturePro(texture, subrect, render_rect, animation.origin, std.math.radiansToDegrees(opt.rotation_radians), opt.tint);
    }

    //updates animation frame and rotation_radians
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
    tilemap_resolution: f32,
    camera: ray.Camera2D,

    pub fn deinit(self: *@This()) void {
        var iter = self.textures.iterator();
        while (iter.next()) |entry| {
            ray.UnloadTexture(entry.value_ptr.*);
        }
        self.animations.deinit();
        self.textures.deinit();
    }

    pub fn updateCameraPosition(self: *@This(), l: level.Level, keybindings: *const key.KeyBindings) void {
        var zoom = self.camera.zoom;
        if (keybindings.isDown("zoom_in") and zoom < 10) zoom *= 1.01;
        if (keybindings.isDown("zoom_out") and zoom > 0.2) zoom *= 0.99;

        const player_id = l.player_id;
        var player_position: ray.Vector2 = l.ecs.get(Component.Physics, player_id).pos;

        player_position.x *= self.tilemap_resolution;
        player_position.y *= self.tilemap_resolution;

        const min_camera_x: f32 = (screenWidth() / 2) / zoom;
        const min_camera_y: f32 = (screenHeight() / 2) / zoom;

        if (player_position.x < min_camera_x) {
            player_position.x = min_camera_x;
        }

        if (player_position.y < min_camera_y) {
            player_position.y = min_camera_y;
        }

        const map_width: f32 = tof32(l.map.width) * self.tilemap_resolution;
        const map_height: f32 = tof32(l.map.height) * self.tilemap_resolution;
        const max_camera_x: f32 = (map_width - min_camera_x);
        const max_camera_y: f32 = (map_height - min_camera_y);

        if (player_position.x > max_camera_x) {
            player_position.x = max_camera_x;
        }

        if (player_position.y > max_camera_y) {
            player_position.y = max_camera_y;
        }

        self.camera = ray.Camera2D{
            .offset = .{ .x = screenWidth() / 2, .y = screenHeight() / 2 },
            .rotation = 0.0,
            .zoom = zoom,
            .target = player_position,
        };
    }

    pub fn init(a: std.mem.Allocator, lua: *Lua) !@This() {
        var self = .{
            .animations = std.StringHashMap(Animation).init(a),
            .textures = std.StringHashMap(ray.Texture2D).init(a),
            .tilemap_resolution = try lua.autoCall(f32, "TilemapResolution", .{}),
            .camera = ray.Camera2D{
                .offset = .{ .x = 0, .y = 0 },
                .rotation = 0.0,
                .zoom = 2,
                .target = .{ .x = 0, .y = 0 },
            },
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

    pub fn mousePosition(self: *const @This()) ray.Vector2 {
        return scaleVector(
            ray.GetScreenToWorld2D(ray.GetMousePosition(), self.camera),
            1.0 / self.tilemap_resolution,
        );
    }

    ///convert Tile Position to Screen Position
    pub fn tileToScreen(self: *const @This(), tile_coordinates: ray.Vector2) ray.Vector2 {
        const world_position = ray.Vector2{
            .x = tile_coordinates.x * self.tilemap_resolution,
            .y = tile_coordinates.y * self.tilemap_resolution,
        };
        return ray.GetWorldToScreen2D(world_position, self.camera);
    }

    ///convert Tile Position to OpenGl Screen Position (normalized coordinates)
    pub fn tileToOpenGl(self: *const @This(), pos: shader.Vec2) shader.Vec2 {
        const screen_pos = self.tileToScreen(pos);

        return shader.Vec2{
            .x = ((screen_pos.x / screenWidth())),
            .y = (1 - (screen_pos.y / screenHeight())),
        };
    }

    ///converts a distance in tiles to a distance in screen pixels
    pub fn tileDistanceToScreen(self: *const @This(), distance_in_tiles: f32) f32 {
        const unzoomed_distance = distance_in_tiles * self.tilemap_resolution;
        const distance = unzoomed_distance * self.camera.zoom;
        return distance;
    }

    ///converts a distance in tiles to a distance in OpenGL Shader Coordinates (Normalized coordinates)
    pub fn tileDistanceHorizontalToOpenGl(self: *const @This(), distance_in_tiles: f32) f32 {
        const screen_distance = self.tileDistanceToScreen(distance_in_tiles);
        return screen_distance / screenWidth();
    }

    ///converts a distance in tiles to a distance in OpenGL Shader Coordinates (Normalized coordinates)
    pub fn tileDistanceVerticalToOpenGl(self: *const @This(), distance_in_tiles: f32) f32 {
        const screen_distance = self.tileDistanceToScreen(distance_in_tiles);
        return screen_distance / screenHeight();
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
    opt: options.Update,
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

            //make sure creation time has been set
            if (sprite.creation_time == null) {
                sprite.creation_time = opt.total_time_ms;
            }

            var render_options = RenderOptions{
                .flipped = physics.vel.x > 0,
            };
            var render_position = physics.pos;

            //account for bobbing
            if (sprite.styling.bob) |bob| {
                const normalized_cycle_progress = (std.math.mod(f32, (opt.total_time_ms - sprite.creation_time.?), bob.cycle_time_ms) catch 0) / bob.cycle_time_ms;
                render_position.y += std.math.sin(normalized_cycle_progress * std.math.pi * 2) * bob.distance;
            }

            //account for lean
            if (sprite.styling.lean) |lean| {
                var raw_lean_angle: f32 = physics.vel.x * lean.resistance;
                if (@abs(raw_lean_angle) > lean.max_angle_radians) {
                    const sign: f32 = if (raw_lean_angle > 0) 1 else -1;
                    raw_lean_angle = lean.max_angle_radians * sign;
                }
                render_options.rotation_radians = raw_lean_angle * -1;
            }

            //account for scaling styling
            if (sprite.styling.scale) |*scale| {
                if (scale.current > scale.min_scale) {
                    scale.current *= scale.rate_of_change;
                } else {
                    scale.current = scale.min_scale;
                }
                render_options.horizontal_scale = scale.current;
                render_options.vertical_scale = scale.current;
            }

            sprite.animation_player.render(animation_state, render_position, render_options);
        }
    }
}
