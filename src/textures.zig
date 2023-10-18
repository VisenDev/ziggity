const std = @import("std");
const file = @import("file_utils.zig");
const ray = @cImport({
    @cInclude("raylib.h");
});
const json = std.json;

pub const RenderOptions = struct {
    scale: f32,
    grid_spacing: f32,
    zoom: f32,

    pub fn getScreenPosition(self: *const @This(), vec: ray.Vector2) ray.Vector2 {
        return ray.Vector2{ .x = vec.x * self.grid_spacing, .y = vec.y * self.grid_spacing };
    }
};

const Records = struct {
    //stores texture records
    textures: []struct {
        name: []u8,
        path: [:0]u8,
        x: f32,
        y: f32,
        width: f32,
        height: f32,
    },
};

pub const TextureState = struct {
    textures: []ray.Texture2D,
    name_index: std.hash_map.StringHashMap(usize),
    default: ray.Texture2D,

    pub fn get(self: *const @This(), key: []const u8) ray.Texture2D {
        if (self.name_index.get(key)) |texture_id| {
            return self.textures[texture_id];
        }
        return self.default;
    }

    pub fn getI(self: *const @This(), id: usize) ray.Texture2D {
        if (id >= self.textures.len) {
            return self.default;
        }
        return self.textures[id];
    }

    pub inline fn search(self: *const @This(), key: []const u8) ?usize {
        return self.name_index.get(key);
    }

    pub fn deinit(self: *const @This()) void {
        //var it = self.textures.iterator();
        for (self.textures) |val| {
            ray.UnloadTexture(val);
        }
    }

    pub fn init(a: std.mem.Allocator) !TextureState {
        const data = try file.readConfig(Records, a, "textures.json");

        var textures = std.ArrayList(ray.Texture2D).init(a);
        var name_index = std.hash_map.StringHashMap(usize).init(a);
        var default: ?ray.Texture2D = null;

        var i: u32 = 0;
        for (data.textures) |val| {
            const path = try file.combineAppendSentinel(a, try file.getImageDirPath(a), val.path);

            var image = ray.LoadImage(path.ptr);
            if (!ray.IsImageReady(image)) {
                return error.invalid_json_data;
            }

            ray.ImageCrop(&image, ray.Rectangle{ .x = val.x, .y = val.y, .width = val.width, .height = val.height });
            if (!ray.IsImageReady(image)) {
                return error.invalid_json_data;
            }

            const texture = ray.LoadTextureFromImage(image);
            if (!ray.IsTextureReady(texture)) {
                return error.invalid_json_data;
            }

            if (std.mem.eql(u8, val.name, "default")) {
                default = texture;
                continue;
            }

            try textures.append(texture);
            try name_index.put(val.name, i);
            i += 1;
        }

        if (default) |_| {} else {
            return error.no_default_texture_provided;
        }
        return .{ .textures = textures.items, .name_index = name_index, .default = default.? };
    }
};
