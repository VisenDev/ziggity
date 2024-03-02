const std = @import("std");
const Component = @import("components.zig");
const options = @import("options.zig");
const ecs = @import("ecs.zig");

pub const decision_fn_ptr = *fn (ecs: *anyopaque, id: usize) u8;
pub const action_fn_ptr = *fn (ecs: *anyopaque, id: usize, num_ms_active: usize) bool;

pub const controller = struct {
    pub const name = "controller";

    pub const Behavior = struct {
        decision_fn_name: []const u8 = "",
        action_fn_name: []const u8 = "",
    };

    behaviors: []Behavior = &.{},
    active_behavior: ?usize = null,
    num_ms_active: usize = 0,
};

pub const ControllerState = struct {
    decision_fns: std.HashMap(decision_fn_ptr),
    action_fns: std.HashMap(action_fn_ptr),

    pub fn init(a: std.mem.Allocator) ControllerState {
        return .{
            .decision_fns = std.HashMap(decision_fn_ptr).init(a),
            .action_fns = std.HashMap(action_fn_ptr).init(a),
        };
    }

    pub fn deinit(self: *@This()) void {
        self.decision_fns.deinit();
        self.action_fns.deinit();
    }

    pub fn registerActionNamespace(self: *ControllerState, namespace: anytype) !void {
        inline for (std.meta.declarations(namespace)) |decl| {
            const value = @field(namespace, decl.name);
            try self.action_fns.put(decl.name, value);
        }
    }

    pub fn registerDecisionNamespace(self: *ControllerState, namespace: anytype) !void {
        inline for (std.meta.declarations(namespace)) |decl| {
            const value = @field(namespace, decl.name);
            try self.decision_fns.put(decl.name, value);
        }
    }
};

pub const basic_decisions = struct {
    pub fn wander(self: *const ecs.ECS, entity: usize) u8 {
        if (self.getMaybe(Component.wanderer, entity) != null) {
            return 10;
        } else return 0;
    }

    pub fn chase(self: *const ecs.ECS, entity: usize) u8 {
        if (self.getMaybe(Component.chase, entity) != null) {
            return 50;
        } else return 0;
    }
};

pub fn updateControllerSystem(self: *ecs.ECS, a: std.mem.Allocator, state: ControllerState, opt: options.Update) !void {
    const systems = [_]type{Component.controller};
    const set = self.getSystemDomain(a, &systems);

    for (set) |member| {
        var ctrl = self.get(Component.controller, member);

        if (ctrl.active_behavior == null) {
            var max_importance: u8 = 0;
            for (ctrl.behaviors, 0..) |behavior, i| {
                const function = try state.decision_fns.get(behavior.decision_fn_name);
                const importance = @call(.auto, function, .{ ecs, member });
                if (importance > max_importance) {
                    max_importance = importance;
                    ctrl.active_behavior = i;
                }
            }
        }

        const chosen_behavior = ctrl.behaviors[ctrl.active_behavior.?];
        const behavior_function = try state.action_fns_fns.get(chosen_behavior.action_fn_name);
        const action_over = @call(.auto, behavior_function, .{ ecs, member, ctrl.num_ms_active });
        ctrl.num_ms_active += opt.dtInMs();

        if (action_over) {
            ctrl.active_behavior = null;
            ctrl.num_ms_active = 0;
        }
    }
}
