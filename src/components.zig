const anime = @import("animation.zig");
const inv = @import("inventory.zig");
const sys = @import("systems.zig");
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
        return .{
            .x = @intFromFloat(@max(@divFloor(self.pos.x, sys.position_cache_scale), 0)),
            .y = @intFromFloat(@max(@divFloor(self.pos.y, sys.position_cache_scale), 0)),
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
    animation_player: anime.AnimationPlayer = .{ .animation_name = "default" },
};
pub const tracker = struct {
    pub const name = "tracker";
    tracked: ?usize = null,
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
    points: []ray.Vector2 = &[_]ray.Vector2{},
};
pub const mind = struct {
    pub const name = "mind";
    activity: enum {
        patrol,
        attack,
        follow,
        stop,
    } = .stop,
};
pub const eyesight = struct {
    pub const name = "eyesight";
    view_range: f32 = 5,
};
pub const loot = struct {
    pub const name = "loot";
    items: []const [:0]const u8 = &[_][:0]const u8{""},
};
pub const hitbox = struct {
    pub const name = "hitbox";
    left: f32 = 0.5,
    right: f32 = 0.5,
    top: f32 = 0.5,
    bottom: f32 = 0.5,

    pub fn getCollisionRect(self: @This(), pos: ray.Vector2) ray.Rectangle {
        return ray.Rectangle{
            .x = pos.x - self.left,
            .y = pos.y - self.top,
            .width = self.left + self.right,
            .height = self.top + self.bottom,
        };
    }
};
pub const damage = struct {
    pub const name = "damage";
    type: []const u8 = "",
    amount: f32 = 10,
};
pub const nametag = struct {
    pub const name = "nametag";
    value: []u8 = "",
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
pub const invulnerable = struct {
    pub const name = "invulnerable";
    filler: u8 = 0, //this field is here because zig does not like when the struct is empty
};
pub const metadata = struct {
    pub const name = "metadata";
    archetype: []const u8 = "unknown",
};
pub const item = inv.ItemComponent;
pub const inventory = inv.InventoryComponent;
//Should I possibly rename this to "useable?" so that more entities than the player can use it?
//or actions?
pub const left_clickable = struct {
    pub const name = "left_clickable";
    function_name: []const u8 = "",
};
pub const right_clickable = struct {
    pub const name = "right_clickable";
    function_name: []const u8 = "",
};
pub const death_particles = struct {
    pub const name = "death_particles";
    color: ray.Color = ray.RED,
    quantity: usize = 20,
};
