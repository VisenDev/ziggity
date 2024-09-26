const std = @import("std");
const move = @import("movement.zig");
const Component = @import("components.zig");
const options = @import("options.zig");
const ecs = @import("ecs.zig");
const ray = @cImport({
    @cInclude("raylib.h");
});

pub const Controller = struct {
    pub const name = "controller";

    active_behavior: ?usize = null,
    num_ms_active: f32 = 0,
};

pub const ActionFnOptions = struct {
    num_ms_active: f32 = 0,
    update: options.Update,
};

pub const action_fn_ptr = *fn (ecs: *ecs.ECS, a: std.mem.Allocator, id: usize, opt: ActionFnOptions) bool;
pub const decision_fn_ptr = *fn (ecs: *const ecs.ECS, id: usize) u8;

fn isBehaviorComponent(comptime ComponentType: type) bool {
    return @hasDecl(ComponentType, "action") and
        @hasDecl(ComponentType, "decision"); // and
}

fn countBehaviorComponents() usize {
    var result: usize = 0;
    inline for (comptime ecs.sliceComponentNames()) |decl| {
        const ComponentType = @field(Component, decl.name);
        if (isBehaviorComponent(ComponentType)) {
            result += 1;
        }
    }
    return result;
}

fn getBehaviorComponents() [countBehaviorComponents()]type {
    var result: [countBehaviorComponents()]type = undefined;
    var num_results: usize = 0;
    for (ecs.sliceComponentNames()) |decl| {
        const ComponentType = @field(Component, decl.name);
        if (isBehaviorComponent(ComponentType)) {
            result[num_results] = ComponentType;
            num_results += 1;
        }
    }
    return result;
}

pub fn updateControllerSystem(self: *ecs.ECS, a: std.mem.Allocator, opt: options.Update) !void {
    const systems = [_]type{Component.Controller};
    const set = self.getSystemDomain(a, &systems);

    for (set) |member| {
        var ctrl = self.get(Component.Controller, member);

        if (ctrl.active_behavior == null) {
            var max_importance: u8 = 0;
            inline for (comptime getBehaviorComponents(), 0..) |BehaviorType, i| {
                if (self.getMaybe(BehaviorType, member) != null) {
                    const importance = BehaviorType.decision(self, member);
                    if (importance > max_importance) {
                        max_importance = importance;
                        ctrl.active_behavior = i;
                    }
                }
            }
        }

        if (ctrl.active_behavior) |active| {
            inline for (comptime getBehaviorComponents(), 0..) |BehaviorType, i| {
                if (active == i) {
                    const done = BehaviorType.action(self, a, member, .{
                        .update = opt,
                        .num_ms_active = ctrl.num_ms_active,
                    });
                    ctrl.num_ms_active += opt.dtInMs();

                    if (done) {
                        ctrl.active_behavior = null;
                        ctrl.num_ms_active = 0;
                    }
                }
            }
        }
    }
}

pub const Wanderer = struct {
    pub const name = "wanderer";
    state: enum { arrived, travelling, waiting, selecting } = .arrived,
    destination: ray.Vector2 = .{ .x = 0, .y = 0 },
    cooldown: f32 = 0,

    pub fn decision(self: *const ecs.ECS, entity: usize) u8 {
        if (self.getMaybe(Component.Wanderer, entity) != null) {
            return 10;
        } else return 0;
    }

    pub fn action(self: *ecs.ECS, a: std.mem.Allocator, entity: usize, opt: ActionFnOptions) bool {
        _ = a;
        const wanderer = self.get(Component.Wanderer, entity);
        switch (wanderer.state) {
            .arrived => {
                wanderer.cooldown = opt.update.dt * 300 * ecs.randomFloat();
                wanderer.state = .waiting;
            },
            .waiting => {
                wanderer.cooldown -= opt.update.dt;
                if (wanderer.cooldown < 0) {
                    wanderer.state = .selecting;
                }
            },
            .selecting => {
                const physics = self.get(Component.Physics, entity);
                const random_vector = ecs.randomVector2(10, 10);
                const random_destination = ray.Vector2{
                    .x = physics.position.x + random_vector.x - 6,
                    .y = physics.position.y + random_vector.y - 6,
                };
                //std.debug.print("old: {}\nnew: {}\n\n", .{ wanderer.destination, random_destination });
                wanderer.destination = random_destination;
                wanderer.state = .travelling;
                wanderer.cooldown = 30 * ecs.randomFloat() * 1000;
            },
            .travelling => {
                const physics = self.get(Component.Physics, entity);
                const direction = move.directionVector(physics.position, wanderer.destination);
                const force = 10;
                physics.applyForce(move.scaleVector(direction, force));
                //move.moveTowards(physics, wanderer.destination, opt.update);
                wanderer.cooldown -= opt.update.dtInMs();

                if (move.distanceBetween(physics.position, wanderer.destination) < 1.5 or wanderer.cooldown <= 0) {
                    wanderer.state = .arrived;
                }
            },
        }
        return true;
    }
};

pub const Faction = struct {
    pub const name = "faction";

    pub const FactionNames = enum {
        player,
        hostile,
    };

    hostile_factions: []FactionNames = &.{.player},
    hostile_entities: []usize,
    peaceful_factions: []FactionNames = &.{.hostile},
    peaceful_entities: []usize,
};

pub const Targeter = struct {
    pub const name = "targeter";
    target: ?usize = null,
};

pub const MeleeAI = struct {
    pub const name = "MeleeAI";
    tracked: ?usize = null,

    pub fn decision(self: *const ecs.ECS, entity: usize) u8 {
        if (self.getMaybe(Component.Targeter, entity) != null) {
            return 50;
        } else return 0;
    }
};
