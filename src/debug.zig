const std = @import("std");
const cam = @import("camera.zig");
const tile = @import("tiles.zig");
const anime = @import("animation.zig");
const map = @import("map.zig");
const texture = @import("textures.zig");
const key = @import("keybindings.zig");
const options = @import("options.zig");
const ecs = @import("ecs.zig");
const SparseSet = @import("sparse_set.zig").SparseSet;
const Grid = @import("grid.zig").Grid;
const coll = @import("collisions.zig");
const Component = @import("components.zig");
const intersection = @import("sparse_set.zig").intersection;
const sys = @import("systems.zig");

const dvui = @import("dvui");
const ray = @import("raylib-import.zig").ray;
//const ray = @cImport({
//    @cInclude("raylib.h");
//});

pub const DebugEntry = struct {
    pub const max_string_length = 256;
    pub const default_font_size = 16;
    pub const PositionType = enum { screen_position, tile_position };

    font_size: f32 = default_font_size,
    font_color: ray.Color,
    text_spacing: f32 = 2,
    position: ray.Vector2,
    position_type: PositionType = .screen_position,
    buffer: [max_string_length]u8 = [_]u8{0} ** max_string_length,
};

pub const DebugRenderer = struct {
    enabled: bool = true,
    entries: std.ArrayList(DebugEntry),
    num_debug_text_rows: f32 = 0,

    pub fn init(a: std.mem.Allocator) !@This() {
        return @This(){
            .entries = try std.ArrayList(DebugEntry).initCapacity(a, 32),
        };
    }

    pub fn deinit(self: *@This()) void {
        self.entries.deinit();
    }

    pub fn render(self: *@This(), window_manager: *const anime.WindowManager) void {
        if (self.enabled) {
            for (self.entries.items) |entry| {
                const position = if (entry.position_type == .tile_position)
                    window_manager.tileToScreen(entry.position)
                else
                    entry.position;

                ray.DrawTextEx(
                    ray.GetFontDefault(),
                    (&entry.buffer).ptr,
                    position,
                    entry.font_size,
                    entry.text_spacing,
                    entry.font_color,
                );
            }
        }
        self.entries.clearRetainingCapacity();
        self.num_debug_text_rows = 0;
    }

    pub fn addTextButton(self: *@This(), wm: *anime.WindowManager, comptime fmt: [:0]const u8, args: anytype) bool {
        const default_offset: f32 = 1;
        const font_size: f32 = 10;
        const coordinates = ray.Vector2{
            .x = default_offset,
            .y = default_offset + font_size * self.num_debug_text_rows,
        };
        self.num_debug_text_rows += 1;

        const mpos = wm.getMouseScreenPosition();

        if (mpos.x > coordinates.x and mpos.y > coordinates.y and mpos.x < coordinates.x + (font_size * fmt.len) and mpos.y < coordinates.y + font_size) {
            if (wm.getMouseOwner() != .debugger) {
                //std.debug.print("Current Owner Before Takeover: {?}\n", .{wm.getMouseOwner()});
                wm.activateMouseOwnership(.debugger);
                //std.debug.print("Current Owner After Takeover: {?}\n\n", .{wm.getMouseOwner()});
            }

            self.addTextAtPosition(coordinates, .screen_position, font_size, ray.GRAY, fmt, args);
            if (wm.getMouseOwner() == .debugger) {
                if (wm.isMousePressed(.left)) {
                    return true;
                }
            }
        } else {
            //wm.relinquishMouseOwnership(.debugger) catch |e| {
            //    std.debug.print("Taking mouse ownership failed {!}\n", .{e});
            //wm.deactivateMouseOwnership(.debugger);
            //std.debug.print("Deactivating Debugger Ownership. New Owner: {?}\n\n", .{wm.getMouseOwner()});
            //};
            self.addTextAtPosition(coordinates, .screen_position, font_size, ray.RAYWHITE, fmt, args);
        }

        return false;
    }

    pub fn addText(self: *@This(), comptime fmt: [:0]const u8, args: anytype) void {
        const default_offset: f32 = 1;
        const font_size: f32 = 10;
        const coordinates = ray.Vector2{
            .x = default_offset,
            .y = default_offset + font_size * self.num_debug_text_rows,
        };
        self.num_debug_text_rows += 1;
        self.addTextAtPosition(coordinates, .screen_position, font_size, ray.RAYWHITE, fmt, args);
    }

    pub fn addTextAtPosition(
        self: *@This(),
        position: ray.Vector2,
        position_type: DebugEntry.PositionType,
        font_size: f32,
        font_color: ray.Color,
        comptime fmt: [:0]const u8,
        args: anytype,
    ) void {
        self.entries.append(DebugEntry{
            .position = position,
            .position_type = position_type,
            .font_size = font_size,
            .font_color = font_color,
        }) catch {
            std.debug.print("failed to allocate debug memory\n", .{});
            return;
        };
        const buffer: []u8 = &self.entries.items[self.entries.items.len - 1].buffer;
        _ = std.fmt.bufPrintZ(buffer, fmt, args) catch "[formatting error]";
        //ray.DrawTextEx(ray.GetFontDefault(), string.ptr, position, self.font_size, self.text_spacing, ray.RAYWHITE);
    }

    //pub fn addTextAtTileCoordinates(self: *@This(), coordinates: ray.Vector2, comptime fmt: [:0]const u8, args: anytype) void {
    //    //const screen_position = cam.tileToScreen(coordinates, self.camera);
    //    const font_size: f32 = 8;
    //    self.addTextAtScreenPosition(screen_position, font_size * self.camera.zoom, fmt, args);
    //}
};

pub const DeltaTimeLog = struct {
    const num_logs = 2048;
    dt: [num_logs]f32 = .{0} ** num_logs,
    index: usize = 0,

    pub fn record(self: *@This(), dt: f32) void {
        self.dt[self.index] = dt;
        self.index += 1;
        if (self.index >= num_logs) {
            self.index = 0;
        }
    }

    pub fn render(self: *@This()) void {
        const pos: ray.Vector2 = .{ .x = anime.screenWidth() - num_logs - 5, .y = anime.screenHeight() - 5 };
        var x_shift: f32 = 0;

        //loop thru first half
        for (self.dt[self.index..]) |dt| {
            ray.DrawLineV(
                .{ .x = pos.x + x_shift, .y = pos.y },
                .{ .x = pos.x + x_shift, .y = pos.y - dt * 1000 },
                ray.RED,
            );
            x_shift += 1;
        }

        //loop thru second half
        for (self.dt[0..self.index]) |dt| {
            ray.DrawLineV(
                .{ .x = pos.x + x_shift, .y = pos.y },
                .{ .x = pos.x + x_shift, .y = pos.y - dt * 1000 },
                ray.RED,
            );
            x_shift += 1;
        }
    }
};

//
//
//
//
//
//
//
//
//
//
//

//const font_size: c_int = 20;
//
//pub fn renderHitboxes(self: *ecs.ECS, a: std.mem.Allocator, tile_state_resolution: usize) void {
//    const systems = [_]type{ Component.physics, Component.hitbox };
//    const set = self.getSystemDomain(a, &systems);
//
//    for (set) |member| {
//        const physics = self.get(Component.physics, member);
//        const hitbox = self.get(Component.hitbox, member);
//
//        const rect = hitbox.getCollisionRect(physics.pos);
//        ray.DrawRectangleLinesEx(sys.scaleRectangle(rect, tile_state_resolution), 1, ray.ColorAlpha(ray.RAYWHITE, 0.4));
//    }
//}
//
//pub fn renderEntityCoordinates() void {}
//
//var buf: [1024]u8 = undefined;
//
//pub fn renderPositionCache(self: *ecs.ECS, a: std.mem.Allocator, tile_state_resolution: usize) void {
//    _ = a;
//    for (0..self.position_cache.getWidth()) |x| {
//        for (0..self.position_cache.getHeight()) |y| {
//            const contents = self.position_cache.get(x, y).?;
//            if (contents.items.len > 0) {
//                const position = ray.Vector2{
//                    .x = sys.tof32(x * sys.position_cache_scale * tile_state_resolution),
//                    .y = sys.tof32(y * sys.position_cache_scale * tile_state_resolution),
//                };
//                const size = sys.tof32(sys.position_cache_scale * tile_state_resolution);
//                ray.DrawRectangleLinesEx(.{ .x = position.x, .y = position.y, .width = size, .height = size }, 1, ray.ColorAlpha(ray.YELLOW, 0.5));
//
//                _ = std.fmt.bufPrintZ(&buf, "{}", .{contents.items.len}) catch unreachable;
//                ray.DrawTextEx(ray.GetFontDefault(), &buf, position, font_size / 2, 2, ray.RAYWHITE);
//            }
//        }
//    }
//}
//
//pub fn renderEntityCount(self: *ecs.ECS) !void {
//    const count = self.capacity - self.availible_ids.items.len;
//
//    _ = try std.fmt.bufPrintZ(&buf, "{} entities", .{count});
//    ray.DrawText(&buf, 15, 45, font_size, ray.RAYWHITE);
//}
//
//pub fn renderWanderDestinations(self: *ecs.ECS, a: std.mem.Allocator) !void {
//    const systems = [_]type{ Component.Wanderer, Component.Physics };
//    const set = self.getSystemDomain(a, &systems);
//
//    for (set, 0..) |member, i| {
//        _ = i;
//
//        const physics = self.get(Component.Physics, member);
//        _ = physics;
//        const wanderer = self.get(Component.Wanderer, member);
//
//        ray.DrawRectangleLinesEx(.{
//            .x = wanderer.destination.x * cam.render_resolution,
//            .y = wanderer.destination.y * cam.render_resolution,
//            .width = 5,
//            .height = 5,
//        }, 1, ray.ColorAlpha(ray.RAYWHITE, 0.4));
//    }
//}
