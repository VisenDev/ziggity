const std = @import("std");
const ray = @cImport({
    @cInclude("raylib.h");
});
const json = std.json;

pub const TextureState = struct {
    textures: std.hash_map.StringHashMap(ray.Texture2D),
    default: ray.Texture2D,
    pub fn get(self: *const @This(), key: []const u8) ray.Texture2D {
        if (self.textures.get(key)) |texture| {
            return texture;
        }
        return self.default;
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

pub fn createTextureState(a: std.mem.Allocator) !TextureState {
    //const stdout = std.io.getStdOut().writer();
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const local = gpa.allocator();

    const string = try std.fs.cwd().readFileAlloc(local, "config/textures.json", 2048);
    defer local.free(string);

    const parsed_data = try json.parseFromSlice(Records, local, string, .{});
    //defer parsed_data.deinit();
    const data = parsed_data.value;

    var default_found = false;
    var state = TextureState{
        .textures = std.hash_map.StringHashMap(ray.Texture2D).init(a),
        .default = undefined,
    };

    for (data.textures) |val| {
        //try stdout.print("{s} {s} {} {} {} {}\n", .{ val.name, val.path, val.x, val.y, val.width, val.height });
        var image = ray.LoadImage(val.path);
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
            state.default = texture;
            default_found = true;
            continue;
        }
        try state.textures.put(val.name, texture);
    }

    if (default_found == false) {
        return error.no_default_texture_provided;
    }
    return state;
}
