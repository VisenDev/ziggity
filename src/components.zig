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
};
pub const health = struct {
    pub const name = "health";
    hp: f32,
    max_hp: f32,
    is_dead: bool,
};
pub const sprite = struct {
    pub const name = "sprite";
    texture_id: usize,
    texture_name: []const u8,
};
pub const tracker = struct {
    pub const name = "tracker";
    tracked: ?usize,
};
pub const movement_particles = struct {
    pub const name = "movement_particles";
    color: ray.Color,
    quantity: u32,
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
pub const collider = struct {
    pub const name = "collider";
    hitbox: ray.Rectangle = .{ .x = -1, .y = -1, .width = 2, .height = 2 },
};
pub const damage = struct {
    pub const name = "damage";
    type: []u8,
    amount: f32,
    cooldown: f32,
    default_cooldown: f32,
};
pub const nametag = struct {
    pub const name = "nametag";
    value: []u8,
};
pub const explode_on_death = struct {
    pub const name = "";
    filler: u8 = 0, //this field is here because zig does not like when the struct is empty
};
pub const is_player = struct {
    pub const name = "is_player";
    filler: u8 = 0, //this field is here because zig does not like when the struct is empty
};
