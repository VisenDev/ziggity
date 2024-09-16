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

const button_opt: dvui.Options = .{
    .background = true,
    .border = dvui.Rect.all(1),
    //.min_size_content = .{ .w = 200 },
};

fn clearBackground() void {
    RaylibBackend.c.ClearBackground(RaylibBackend.dvuiColorToRaylib(dvui.themeGet().color_fill));
}

pub fn drawMainMenu(a: std.mem.Allocator, ui: *dvui.Window, backend: *RaylibBackend) !NextWindow {
    _ = a; // autofix

    while (!ray.WindowShouldClose()) {
        ray.BeginDrawing();
        {
            try ui.begin(std.time.nanoTimestamp());
            defer _ = ui.end(.{}) catch @panic("end failed");

            //var scaler = try dvui.scale(@src(), 2, .{ .expand = .both });
            //defer scaler.deinit();

            clearBackground();

            _ = try backend.addAllEvents(ui);

            if (dvui.themeGet() != &dvui.Theme.Jungle) {
                dvui.themeSet(&dvui.Theme.Jungle);
            }

            if (try dvui.button(@src(), "PLAY", .{}, button_opt)) {
                return .save_menu;
            }

            if (try dvui.button(@src(), "CONFIG", .{}, button_opt)) {
                return .config_menu;
            }

            if (try dvui.button(@src(), "QUIT", .{}, button_opt)) {
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
            defer _ = ui.end(.{}) catch @panic("end failed");

            clearBackground();
            _ = try backend.addAllEvents(ui);

            var vbox = try dvui.box(@src(), .horizontal, .{ .expand = .vertical });
            defer vbox.deinit();

            {
                var hbox = try dvui.box(@src(), .vertical, .{});
                defer hbox.deinit();

                if (try dvui.button(@src(), "Create New", .{}, button_opt)) {
                    return .new_save;
                }

                if (try dvui.button(@src(), "Return to Main Menu", .{}, button_opt)) {
                    return .main_menu;
                }
            }

            try dvui.separator(@src(), .{
                .expand = .vertical,
                .min_size_content = .{ .w = 2 },
                .margin = dvui.Rect.all(4),
            });

            {
                var box = try dvui.box(@src(), .vertical, .{});
                defer box.deinit();

                try dvui.labelNoFmt(@src(), "Available Saves", .{});

                try dvui.separator(@src(), .{
                    .expand = .horizontal,
                    .min_size_content = .{ .h = 2 },
                    .margin = dvui.Rect.all(4),
                });

                //{
                //  var file_box = try dvui.box(@src(), .vertical, .{});
                //defer file_box.deinit();

                {
                    var scroll_box = try dvui.box(@src(), .vertical, .{
                        .min_size_content = .{ .h = 500 },
                    });
                    defer scroll_box.deinit();

                    var scroll_area = try dvui.scrollArea(@src(), .{}, .{ .expand = .vertical });
                    defer scroll_area.deinit();

                    for (files.items, 0..) |filename, i| {
                        if (try dvui.button(@src(), filename, .{}, .{
                            .id_extra = i,
                            .border = dvui.Rect.all(1),
                            .background = true,
                            .min_size_content = .{ .w = 200 },
                            .color_fill = .{
                                .name = if (selected_file_index == i) .accent else .fill,
                            },
                        })) {
                            if (selected_file_index == null) {
                                selected_file_index = i;
                            } //else if (selected_file_index.? == i) {
                            //    selected_file_index = null;
                            //} else {
                            //    selected_file_index = i;
                            //}
                        }
                        //  }
                    }

                    const Followup = struct {
                        var load_save: bool = false;

                        fn callAfter(id: u32, response: dvui.enums.DialogResponse) !void {
                            //var buf: [100]u8 = undefined;
                            //const text = std.fmt.bufPrint(&buf, "You clicked \"{s}\"", .{@tagName(response)}) catch unreachable;
                            //try dvui.dialog(@src(), .{ .title = "Ok Followup Response", .message = text });
                            //dvui.dataSet(null, id, "load_save", response == .ok);
                            load_save = response == .ok;
                            _ = id;
                        }
                    };

                    if (selected_file_index != null) {
                        _ = try dvui.dialog(@src(), .{
                            .message = "hi",
                            .callafterFn = Followup.callAfter,
                        });
                    }

                    if (Followup.load_save) {
                        save_id.* = try a.dupeZ(u8, files.items[selected_file_index.?]);
                        return .game;
                    } else {
                        //selected_file_index = null;
                    }

                    //try dvui.separator(@src(), .{
                    //    .expand = .horizontal,
                    //    .min_size_content = .{ .h = 2 },
                    //    .margin = dvui.Rect.all(4),
                    //});

                    //if (selected_file_index) |i| {
                    //    if (try dvui.button(@src(), "Open", .{}, .{
                    //        .id_extra = i,
                    //        .border = dvui.Rect.all(1),
                    //        .background = true,
                    //        .min_size_content = .{ .w = 200 },
                    //    })) {
                    //        save_id.* = try a.dupeZ(u8, files.items[i]);
                    //        return .game;
                    //    }
                    //}
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
        defer _ = ui.end(.{}) catch @panic("end failed");

        _ = try backend.addAllEvents(ui);

        clearBackground();

        {
            var hbox = try dvui.box(@src(), .horizontal, .{});
            defer hbox.deinit();

            try dvui.label(@src(), "Enter Name", .{}, .{});
            const entry = try dvui.textEntry(@src(), .{ .text = .{ .buffer = &save_name } }, .{});
            entry.deinit();
        }

        {
            var hbox = try dvui.box(@src(), .horizontal, .{});
            defer hbox.deinit();

            try dvui.label(@src(), "Enter Seed", .{}, .{});
            const result = try dvui.textEntryNumber(@src(), usize, .{}, .{});
            if (result == .Valid) {
                seed = result.Valid;
            }
        }
        if (try dvui.button(@src(), "Generate", .{}, .{ .border = dvui.Rect.all(1), .background = true })) {
            std.debug.print("button pressed\n", .{});
            //_ = try ui.end(.{});
            try level.createNewSave(a, lua, .{
                .save_id = std.mem.sliceTo(&save_name, 0),
                .seed = @intCast(@abs(seed)),
            });

            return .save_menu;
        }

        ray.EndDrawing();
    }

    return .quit;
}
