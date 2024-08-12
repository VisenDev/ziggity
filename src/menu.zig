const std = @import("std");
const Lua = @import("ziglua").Lua;
const file = @import("file_utils.zig");
const save = @import("save.zig");
const level = @import("level.zig");
const ray = @cImport({
    @cInclude("raylib.h");
});

//const raygui = @cImport({
//    @cInclude("raygui.h");
//});

const gui = @import("gui.zig");
const dvui = @import("dvui");
const RaylibBackend = @import("RaylibBackend");

pub const NextWindow = enum { main_menu, game, save_menu, config_menu, quit, new_save };

//fn backgroundColor() ray.Color {
//    return ray.GetColor(@intCast(ray.GuiGetStyle(ray.DEFAULT, ray.BACKGROUND_COLOR)));
//}

pub fn drawMainMenu(a: std.mem.Allocator, ui: *dvui.Window, backend: *RaylibBackend) !NextWindow {
    _ = a; // autofix

    while (!ray.WindowShouldClose()) {
        ray.BeginDrawing();
        ray.ClearBackground(ray.BLACK);
        //backend.processRaylibDrawCalls();
        {
            try ui.begin(std.time.nanoTimestamp());
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
    // var gui_manager = gui.RayGuiManager.init(a);
    // defer gui_manager.deinit();

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
        //gui_manager.update();
        ray.BeginDrawing();
        //ray.ClearBackground(gui_manager.backgroundColor());

        ray.ClearBackground(ray.BLACK);
        //backend.processRaylibDrawCalls();
        {
            try ui.begin(std.time.nanoTimestamp());
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

                var scroll_area = try dvui.scrollArea(@src(), .{}, .{ .expand = .both, .background = false });
                defer scroll_area.deinit();

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

            //if (gui_manager.button("Create New")) {
            //    return .new_save;
            //}

            //if (gui_manager.button("Return To Main Menu")) {
            //    return .main_menu;
            //}

            //gui_manager.column();

            //try gui_manager.startScrollPanel("saves list", 6, @floatFromInt(files.items.len));
            //for (files.items, 0..) |filename, i| {
            //    if (gui_manager.button(filename)) {
            //        selected_file_index = i;
            //    }
            //}
            //gui_manager.endScrollPanel();

            //gui_manager.column();

            //if (selected_file_index) |i| {
            //    gui_manager.title(files.items[i]);
            //    if (gui_manager.button("open")) {
            //        save_id.* = try a.dupeZ(u8, files.items[i]);
            //        return .game;
            //    }
            //    gui_manager.line();
            //    if (gui_manager.button("close")) {
            //        selected_file_index = null;
            //    }
            //    gui_manager.column();
            //}
        }

        ray.EndDrawing();
    }

    return .quit;
}

pub fn drawNewSaveMenu(a: std.mem.Allocator, lua: *Lua) !NextWindow {
    var save_name: [:0]const u8 = undefined;
    var seed: usize = 123321;
    var gui_manager = gui.RayGuiManager.init(a);
    defer gui_manager.deinit();

    while (!ray.WindowShouldClose()) {
        gui_manager.update();
        ray.BeginDrawing();
        ray.ClearBackground(gui_manager.backgroundColor());

        save_name = try gui_manager.textBox("Save Name");
        seed = try gui_manager.valueBox(usize, "Numeric Seed");

        if (gui_manager.button("Generate")) {
            try level.createNewSave(a, lua, .{
                .save_id = save_name,
                .seed = @intCast(@abs(seed)),
            });
            return .save_menu;
        }

        ray.EndDrawing();
    }

    return .quit;
}
