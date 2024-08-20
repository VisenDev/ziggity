const std = @import("std");
const Lua = @import("ziglua").Lua;
const file = @import("file_utils.zig");
const save = @import("save.zig");
const level = @import("level.zig");
const ray = @cImport({
    @cInclude("raylib.h");
});

const RaylibBackend = @import("RaylibBackend");

const dvui = @import("dvui");

pub const NextWindow = enum { main_menu, game, save_menu, config_menu, quit, new_save };

fn clearBackground() void {
    RaylibBackend.c.ClearBackground(RaylibBackend.dvuiColorToRaylib(dvui.themeGet().color_fill));
}

pub fn drawMainMenu(a: std.mem.Allocator, ui: *dvui.Window, backend: *RaylibBackend) !NextWindow {
    _ = a; // autofix

    while (!ray.WindowShouldClose()) {
        ray.BeginDrawing();
        {
            try ui.begin(std.time.nanoTimestamp());

            clearBackground();

            defer _ = ui.end(.{}) catch @panic("end failed");
            _ = try backend.addAllEvents(ui);

            if (dvui.themeGet() != &dvui.Theme.Jungle) {
                dvui.themeSet(&dvui.Theme.Jungle);
            }

            if (try dvui.button(@src(), "PLAY", .{}, .{})) {
                return .save_menu;
            }

            if (try dvui.button(@src(), "CONFIG", .{}, .{})) {
                return .config_menu;
            }

            if (try dvui.button(@src(), "QUIT", .{}, .{})) {
                return .quit;
            }
        }
        ray.EndDrawing();
    }
    return .quit;
}

pub fn listFiles(a: std.mem.Allocator, dir: std.fs.Dir) !std.ArrayList([:0]const u8) {
    var iterator = dir.iterate();
    var result = std.ArrayList([:0]const u8).init(a);

    while (try iterator.next()) |entry| {
        try result.append(try a.dupeZ(u8, entry.name));
    }

    std.sort.pdq([:0]const u8, result.items, {}, struct {
        fn lt(_: void, l: [:0]const u8, r: [:0]const u8) bool {
            return std.ascii.lessThanIgnoreCase(l, r);
        }
    }.lt);

    return result;
}

pub fn drawSaveSelectMenu(a: std.mem.Allocator, ui: *dvui.Window, backend: *RaylibBackend, save_id: *[]u8) !NextWindow {
    const path = try file.getSaveDirPath(a);
    const save_dir = std.fs.openDirAbsolute(path, .{ .iterate = true }) catch |e| switch (e) {
        error.FileNotFound => blk: {
            try std.fs.makeDirAbsolute(path);
            break :blk try std.fs.openDirAbsolute(path, .{ .iterate = true });
        },
        else => return e,
    };
    const files = try listFiles(a, save_dir);
    defer {
        for (files.items) |item| {
            a.free(item);
        }
        files.deinit();
    }

    var selected_file_index: ?usize = null;

    while (!ray.WindowShouldClose()) {
        ray.BeginDrawing();
        {
            try ui.begin(std.time.nanoTimestamp());
            clearBackground();
            defer _ = ui.end(.{}) catch @panic("end failed");
            _ = try backend.addAllEvents(ui);

            var vbox = try dvui.box(@src(), .horizontal, .{ .expand = .vertical });
            defer vbox.deinit();

            {
                var hbox = try dvui.box(@src(), .vertical, .{});
                defer hbox.deinit();

                if (try dvui.button(@src(), "Create New", .{}, .{})) {
                    return .new_save;
                }

                if (try dvui.button(@src(), "Return to Main Menu", .{}, .{})) {
                    return .main_menu;
                }
            }

            {
                var box = try dvui.box(@src(), .vertical, .{});
                defer box.deinit();

                try dvui.labelNoFmt(@src(), "Available Saves", .{});

                //var scroll_area = try dvui.scrollArea(@src(), .{}, .{});
                //defer scroll_area.deinit();

                {
                    var file_box = try dvui.box(@src(), .vertical, .{
                        .margin = .{ .x = 10 },
                        .color_border = .{ .color = dvui.themeGet().color_border },
                    });
                    defer file_box.deinit();

                    for (files.items, 0..) |filename, i| {
                        if (try dvui.button(@src(), filename, .{}, .{ .id_extra = i })) {
                            selected_file_index = i;
                        }
                    }
                }
            }

            if (selected_file_index) |i| {
                var hbox = try dvui.box(@src(), .vertical, .{ .margin = .{ .x = 10 }, .color_border = .{ .color = dvui.themeGet().color_border } });
                defer hbox.deinit();

                try dvui.label(@src(), "Save: {s}", .{files.items[i]}, .{});

                if (try dvui.button(@src(), "Open", .{}, .{ .id_extra = i })) {
                    save_id.* = try a.dupeZ(u8, files.items[i]);
                    return .game;
                }

                if (try dvui.button(@src(), "Close", .{}, .{ .id_extra = i })) {
                    selected_file_index = null;
                }
            }
        }

        ray.EndDrawing();
    }

    return .quit;
}

pub fn drawNewSaveMenu(a: std.mem.Allocator, lua: *Lua, ui: *dvui.Window, backend: *RaylibBackend) !NextWindow {
    var save_name: [64]u8 = .{0} ** 64;
    var seed: usize = 123321;

    while (!ray.WindowShouldClose()) {
        ray.BeginDrawing();
        try ui.begin(std.time.nanoTimestamp());
        _ = try backend.addAllEvents(ui);

        clearBackground();

        {
            var hbox = try dvui.box(@src(), .horizontal, .{});
            defer hbox.deinit();

            try dvui.label(@src(), "Enter Name", .{}, .{});
            const entry = try dvui.textEntry(@src(), .{ .text = &save_name }, .{});
            entry.deinit();
        }

        std.debug.print("box drawn\n", .{});
        {
            var hbox = try dvui.box(@src(), .horizontal, .{});
            defer hbox.deinit();

            try dvui.label(@src(), "Enter Seed", .{}, .{});
            const result = try dvui.textEntryNumber(@src(), usize, .{}, .{});
            if (result == .Valid) {
                seed = result.Valid;
            }
        }
        std.debug.print("box drawn2\n", .{});

        if (try dvui.button(@src(), "Generate", .{}, .{})) {
            std.debug.print("button pressed\n", .{});
            //_ = try ui.end(.{});
            try level.createNewSave(a, lua, .{
                .save_id = std.mem.sliceTo(&save_name, 0),
                .seed = @intCast(@abs(seed)),
            });

            return .save_menu;
        }

        _ = try ui.end(.{});
        ray.EndDrawing();
    }

    return .quit;
}
