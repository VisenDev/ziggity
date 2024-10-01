const anime = @import("animation.zig");
const light = @import("light.zig");
const ai = @import("ai.zig");
const inv = @import("inventory.zig");
const control = @import("controller.zig");
const sys = @import("systems.zig");

const dvui = @import("dvui");
const ray = dvui.backend.c;

pub const Physics = @import("movement.zig").Physics;
pub const Health = struct {
    hp: f32 = 10,
    max_hp: f32 = 10,
    is_dead: bool = false,
    cooldown_remaining: f32 = 0,
    pub const damage_cooldown: u32 = 150;
};
pub const Sprite = anime.SpriteComponent;
//pub const Tracker = ai.Targeter;
pub const MovementParticles = struct {
    color: ray.Color = ray.WHITE,
    cooldown_remaining_ms: f32 = 0,
    //quantity: u32 = 1,
};
pub const Wanderer = ai.Wanderer;
pub const Patroller = struct {
    points: []ray.Vector2 = &[_]ray.Vector2{},
};
pub const Controller = ai.Controller;
pub const Eyesight = struct {
    view_range: f32 = 5,
};
pub const Loot = struct {
    items: []const [:0]const u8 = &[_][:0]const u8{""},
};
pub const Hitbox = struct {
    left: f32 = 0.0,
    right: f32 = 0.9,
    top: f32 = 0.0,
    bottom: f32 = 0.9,

    pub fn getCollisionRect(self: @This(), pos: ray.Vector2) ray.Rectangle {
        return ray.Rectangle{
            .x = pos.x - self.left,
            .y = pos.y - self.top,
            .width = self.left + self.right,
            .height = self.top + self.bottom,
        };
    }

    pub fn findCenterCoordinates(self: @This(), entity_position: ray.Vector2) ray.Vector2 {
        return .{
            .x = entity_position.x + (self.right - self.left) / 2,
            .y = entity_position.y + (self.bottom - self.top) / 2,
        };
    }
};
pub const Damage = struct {
    type: []const u8 = "",
    amount: f32 = 10,
};
pub const Nametag = struct {
    value: []u8 = "",
};
pub const IsPlayer = struct {};
pub const Lifetime = struct {
    milliseconds_life_remaining: f32,
};
pub const Invulnerable = struct {
    filler: u8 = 0, //this field is here because zig does not like when the struct is empty
};
pub const Metadata = struct {
    archetype: []const u8 = "unknown",
};
pub const Item = inv.ItemComponent;
pub const Inventory = inv.InventoryComponent;
//Should I possibly rename this to "useable?" so that more entities than the player can use it?
//or actions?
pub const LeftClickable = struct {
    function_name: []const u8 = "",
};
pub const RightClickable = struct {
    function_name: []const u8 = "",
};
pub const DeathParticles = struct {
    color: ray.Color = ray.RED,
    quantity: usize = 20,
};
pub const DeathAnimation = struct {
    animation_name: []const u8 = "",
};
//if an entity has this component it will die whenever its animation stops looping
pub const DieWithAnimation = struct {};

pub const WallCollisions = struct {};

pub const EntityCollisions = struct {};

pub const Light = light.LightComponent;
