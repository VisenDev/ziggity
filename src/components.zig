const anime = @import("animation.zig");
const ray = @cImport({
    @cInclude("raylib.h");
});

const vec_default: ray.Vector2 = .{ .x = 0, .y = 0 };
pub const physics = struct {
    pub const name = "physics";

    pos: ray.Vector2 = vec_default,
    vel: ray.Vector2 = vec_default,

    //internal, should usually be treated as constants
    acceleration: f32 = 0.02,
    friction: f32 = 0.96,

    pub fn getCachePosition(self: @This()) struct { x: usize, y: usize } {
        const position_cache_scaling_factor = 4;
        return .{
            .x = @intFromFloat(@max(@divFloor(self.pos.x, position_cache_scaling_factor), 0)),
            .y = @intFromFloat(@max(@divFloor(self.pos.y, position_cache_scaling_factor), 0)),
        };
    }
};
pub const health = struct {
    pub const name = "health";
    hp: f32 = 10,
    max_hp: f32 = 10,
    is_dead: bool = false,
    cooldown_remaining: f32 = 0,
    pub const damage_cooldown: u32 = 150;
};
pub const sprite = struct {
    pub const name = "sprite";
    player: anime.AnimationPlayer,
};
pub const tracker = struct {
    pub const name = "tracker";
    tracked: ?usize,
};
pub const movement_particles = struct {
    pub const name = "movement_particles";
    color: ray.Color = ray.WHITE,
    quantity: u32 = 1,
};
pub const wanderer = struct {
    pub const name = "wanderer";
    state: enum { arrived, travelling, waiting, selecting } = .arrived,
    destination: ray.Vector2 = vec_default,
    cooldown: f32 = 0,
};
pub const patroller = struct {
    pub const name = "patroller";
    points: []ray.Vector2,
};
pub const mind = struct {
    pub const name = "mind";
    activity: enum {
        patrol,
        attack,
        follow,
        stop,
    },
};
pub const eyesight = struct {
    pub const name = "eyesight";
    view_range: f32,
};
pub const loot = struct {
    pub const name = "loot";
    item_ids: []usize,
};
pub const hitbox = struct {
    pub const name = "hitbox";
    left: f32 = 0.5,
    right: f32 = 0.5,
    top: f32 = 0.5,
    bottom: f32 = 0.5,
};
pub const damage = struct {
    pub const name = "damage";
    type: []const u8 = "",
    amount: f32 = 10,
};
pub const nametag = struct {
    pub const name = "nametag";
    value: []u8,
};
pub const explode_on_death = struct {
    pub const name = "explode_on_death";
    filler: u8 = 0, //this field is here because zig does not like when the struct is empty
};
pub const is_player = struct {
    pub const name = "is_player";
    filler: u8 = 0, //this field is here because zig does not like when the struct is empty
};
pub const health_trickle = struct {
    pub const name = "health_trickle";
    decrease_per_tick: f32 = 10,
};
