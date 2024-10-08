const std = @import("std");
const move = @import("movement.zig");
const MapState = @import("map.zig").MapState;
const shader = @import("shaders.zig");
const key = @import("keybindings.zig");
const level = @import("level.zig");
const cam = @import("camera.zig");
const tile = @import("tiles.zig");
const Component = @import("components.zig");
const ECS = @import("ecs.zig").ECS;
const camera = @import("camera.zig");
const Lua = @import("ziglua").Lua;
const file = @import("file_utils.zig");
const options = @import("options.zig");
const SparseSet = @import("sparse_set.zig").SparseSet;
const dvui = @import("dvui");

const ray = @import("raylib-import.zig").ray;
fn tof32(input: anytype) f32 {
    return @floatFromInt(input);
}

pub fn addVector2(a: ray.Vector2, b: ray.Vector2) ray.Vector2 {
    return .{ .x = a.x + b.x, .y = a.y + b.y };
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
            max_angle_radians: f32 = std.math.pi / 4.0,
            resistance: f32 = 0.1,
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
    width_override: ?f32 = null,
    height_override: ?f32 = null,
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

    pub fn renderOnScreen(self: *const @This(), state: *const WindowManager, screen_position: ray.Vector2, opt: RenderOptions) void {
        self.renderInternal(state, screen_position, opt, .on_screen);
    }

    pub fn renderInWorld(self: *const @This(), state: *const WindowManager, tilemap_position: ray.Vector2, opt: RenderOptions) void {
        self.renderInternal(state, tilemap_position, opt, .in_world);
    }

    //renders the animation
    const RenderLocation = enum { in_world, on_screen };
    fn renderInternal(self: *const @This(), state: *const WindowManager, position: ray.Vector2, opt: RenderOptions, render_location: RenderLocation) void {
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
                .width = @as(f32, @floatFromInt(texture.width)) + 0.1,
                .height = @as(f32, @floatFromInt(texture.height)) + 0.1,
            };

        const subrect = if (opt.flipped) flipSelection(unflipped_subrect) else unflipped_subrect;

        const tilemap_adjustment_factor: f32 = if (render_location == .in_world) state.tilemap_resolution else 1;

        const render_width = if (opt.width_override) |width| width else unflipped_subrect.width;
        const render_height = if (opt.height_override) |height| height else unflipped_subrect.height;

        const render_rect =
            ray.Rectangle{
            .x = position.x * tilemap_adjustment_factor,
            .y = position.y * tilemap_adjustment_factor,
            .width = (render_width * opt.horizontal_scale) + 0.01,
            .height = (render_height * opt.vertical_scale) + 0.01,
        };

        ray.DrawTexturePro(texture, subrect, render_rect, animation.origin, std.math.radiansToDegrees(opt.rotation_radians), opt.tint);
    }

    //updates animation frame and rotation_radians
    pub fn update(self: *@This(), state: *const WindowManager, opt: options.Update) void {
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

pub const MouseButton = enum {
    left,
    right,
    middle,

    pub fn getRayId(self: @This()) c_int {
        return switch (self) {
            .left => ray.MOUSE_BUTTON_LEFT,
            .right => ray.MOUSE_BUTTON_RIGHT,
            .middle => ray.MOUSE_BUTTON_MIDDLE,
        };
    }
};

pub const WindowManager = struct {
    animations: std.StringHashMap(Animation),
    textures: std.StringHashMap(ray.Texture2D),
    tilemap_resolution: f32,
    camera: ray.Camera2D,
    ui_zoom: f32 = 1.0, //TODO configure this in the lua config file
    keybindings: key.KeyBindings,
    mouse_state: MouseState = .{},
    const MouseOwner = std.meta.FieldEnum(MouseState);

    ///Possible owners ranked in terms of priority
    const MouseState = struct {
        debugger: bool = false,
        inventory: bool = false,
        level: bool = true, //should always be true

        pub fn getCurrentOwner(self: @This()) MouseOwner {
            inline for (@typeInfo(@This()).Struct.fields) |field| {
                if (@field(self, field.name)) {
                    return @field(MouseOwner, field.name);
                }
            }
            return .level;
        }
    };

    pub fn deinit(self: *@This()) void {
        var iter = self.textures.iterator();
        while (iter.next()) |entry| {
            ray.UnloadTexture(entry.value_ptr.*);
        }
        self.animations.deinit();
        self.textures.deinit();
    }

    pub fn isMouseDown(self: @This(), button: MouseButton) bool {
        _ = self; // autofix
        return ray.IsMouseButtonDown(button.getRayId());
    }

    pub fn isMousePressed(self: @This(), button: MouseButton) bool {
        _ = self; // autofix
        return ray.IsMouseButtonPressed(button.getRayId());
    }

    pub fn isMouseUp(self: @This(), button: MouseButton) bool {
        _ = self; // autofix
        return ray.IsMouseButtonUp(button.getRayId());
    }

    pub fn getMouseOwner(self: *const @This()) MouseOwner {
        return self.mouse_state.getCurrentOwner();
    }

    pub fn activateMouseOwnership(self: *@This(), comptime owner: MouseOwner) void {
        @field(self.mouse_state, @tagName(owner)) = true;
    }

    pub fn deactivateMouseOwnership(self: *@This(), comptime owner: MouseOwner) void {
        @field(self.mouse_state, @tagName(owner)) = false;
    }

    pub fn resetMouseOwner(self: *@This()) void {
        self.mouse_state = .{};
    }

    pub fn getMouseTileCoordinates(self: *const @This()) ray.Vector2 {
        return scaleVector(
            ray.GetScreenToWorld2D(ray.GetMousePosition(), self.camera),
            1.0 / self.tilemap_resolution,
        );
    }

    pub fn getMouseScreenPosition(self: *const @This()) ray.Vector2 {
        _ = self; // autofix
        return ray.GetMousePosition();
    }

    pub const SubSection = struct {
        min_x: usize,
        min_y: usize,
        max_x: usize,
        max_y: usize,
    };

    pub fn getPlayerId(_: *const @This(), a: std.mem.Allocator, ecs: *ECS) usize {
        const systems = [_]type{Component.IsPlayer};
        const set = ecs.getSystemDomain(a, &systems);
        return set[0];
    }

    pub fn getPlayerHeldItem(self: *const @This(), a: std.mem.Allocator, ecs: *ECS) ?usize {
        return ecs.get(Component.Inventory, self.getPlayerId(a, ecs)).getSelectedItemId();
    }

    pub fn getVisibleBounds(self: *const @This(), a: std.mem.Allocator, ecs: *ECS, map: *const MapState) SubSection {
        const player_position = ecs.get(Component.Physics, self.getPlayerId(a, ecs)).position;

        return .{
            .min_x = @intFromFloat(@floor(@max(player_position.x - (self.screenWidthInTiles() / 2) - 1, 0))),
            .min_y = @intFromFloat(@floor(@max(player_position.y - (self.screenHeightInTiles() / 2) - 1, 0))),
            .max_x = @intFromFloat(@floor(@min(player_position.x + (self.screenWidthInTiles() / 2) + 1, @as(f32, @floatFromInt(map.grid.width - 1))))),
            .max_y = @intFromFloat(@floor(@min(player_position.y + (self.screenWidthInTiles() / 2) + 1, @as(f32, @floatFromInt(map.grid.height - 1))))),
        };

        //@max(@as(usize, @intFromFloat(@floor(player_position.x - self.screenWidthInTiles() / 2))), 0),
        //@max(@as(usize, @intFromFloat(@floor(player_position.y - self.screenHeightInTiles() / 2))), 0),
        //@min(@as(usize, @intFromFloat(@floor(player_position.x + self.screenWidthInTiles() / 2))), map.grid.width),
        //@min(@as(usize, @intFromFloat(@floor(player_position.y + self.screenHeightInTiles() / 2))), map.grid.height),
    }

    /// get the width of a tile in pixels once it is rendered on screen
    pub fn getTileScreenWidth(self: *const @This()) f32 {
        return self.camera.zoom * self.tilemap_resolution;
    }

    pub fn screenHeightInTiles(self: *const @This()) f32 {
        return screenHeight() / self.getTileScreenWidth();
    }

    pub fn screenWidthInTiles(self: *const @This()) f32 {
        return screenWidth() / self.getTileScreenWidth();
    }

    pub fn updateCameraPosition(self: *@This(), a: std.mem.Allocator, l: level.Level) void {
        var zoom = self.camera.zoom;
        if (self.keybindings.isDown("zoom_in") and zoom < 10) zoom *= 1.01;
        if (self.keybindings.isDown("zoom_out") and zoom > 0.2) zoom *= 0.99;

        const systems = [_]type{Component.IsPlayer};
        const set = l.ecs.getSystemDomain(a, &systems);
        var player_position = l.ecs.get(Component.Physics, set[0]).position;

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

        const map_width: f32 = tof32(l.map.grid.width) * self.tilemap_resolution;
        const map_height: f32 = tof32(l.map.grid.height) * self.tilemap_resolution;
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
            .tilemap_resolution = try lua.get(f32, "TilemapResolution"),
            .camera = ray.Camera2D{
                .offset = .{ .x = 0, .y = 0 },
                .rotation = 0.0,
                .zoom = 2,
                .target = .{ .x = 0, .y = 0 },
            },
            .keybindings = try key.KeyBindings.init(a, lua),
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

    //pub fn rawMouseScreenPosition(self: *const @This()) ray.Vector2 {
    //    return scaleVector(
    //        ray.GetScreenToWorld2D(ray.GetMousePosition(), self.camera),
    //        1.0 / self.tilemap_resolution,
    //    );
    //}
    //

    ///
    pub fn tileToWorld(self: *const @This(), tile_coordinates: ray.Vector2) ray.Vector2 {
        const world_position = ray.Vector2{
            .x = tile_coordinates.x * self.tilemap_resolution,
            .y = tile_coordinates.y * self.tilemap_resolution,
        };
        return world_position;
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
    self: *ECS,
    a: std.mem.Allocator,
    window_manager: *const WindowManager,
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
                .flipped = physics.velocity.x > 0,
            };
            var render_position = physics.position;

            //account for bobbing
            if (sprite.styling.bob) |bob| {
                const normalized_cycle_progress = (std.math.mod(f32, (opt.total_time_ms - sprite.creation_time.?), bob.cycle_time_ms) catch 0) / bob.cycle_time_ms;
                render_position.y -= @abs(std.math.sin(normalized_cycle_progress * std.math.pi * 2)) *
                    (bob.distance * (move.getMagnitude(physics.velocity) + 0.1));
            }

            //account for lean
            if (sprite.styling.lean) |lean| {
                var raw_lean_angle: f32 = physics.velocity.x * lean.resistance;
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

            sprite.animation_player.renderInWorld(window_manager, render_position, render_options);
        }
    }
}
