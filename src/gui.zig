const anime = @import("animation.zig");
const std = @import("std");
const ray = @cImport({
    @cInclude("raylib.h");
});

const raygui = @cImport({
    @cInclude("raygui.h");
});

pub const styles = @cImport({
    @cInclude("stdlib.h");
    @cInclude("string.h");
    @cInclude("raygui.h");
    @cInclude("style_amber.h");
    @cInclude("style_ashes.h");
    @cInclude("style_bluish.h");
    @cInclude("style_candy.h");
    @cInclude("style_cherry.h");
    @cInclude("style_cyber.h");
    @cInclude("style_dark.h");
    @cInclude("style_enefete.h");
    @cInclude("style_jungle.h");
    @cInclude("style_lavanda.h");
    @cInclude("style_sunny.h");
    @cInclude("style_terminal.h");
});

pub const RayGuiManager = struct {
    widget_padding: f32 = 10,
    text_size: c_int = 15,
    widget_width: f32 = 150,
    widget_height: f32 = 30,
    active_x: f32 = 10,
    active_y: f32 = 10,

    text_box_mode: std.StringHashMap(bool) = undefined,
    text_box_text: std.StringHashMap(StringBuffer) = undefined,

    dropdown_box_mode: std.StringHashMap(bool) = undefined,

    style_changed: bool = true,

    const StringBuffer = [256:0]u8;
    const empty_buffer: StringBuffer = .{0} ** 256;

    ///selected style index
    var selected_style: usize = 6;

    pub fn init(a: std.mem.Allocator) @This() {
        return .{
            .text_box_mode = std.StringHashMap(bool).init(a),
            .text_box_text = std.StringHashMap(StringBuffer).init(a),
            .dropdown_box_mode = std.StringHashMap(bool).init(a),
        };
    }

    pub fn deinit(self: *@This()) void {
        self.text_box_mode.deinit();
        self.text_box_text.deinit();
        self.dropdown_box_mode.deinit();
    }

    pub fn backgroundColor(self: *const @This()) ray.Color {
        _ = self; // autofix
        const hex: c_int = raygui.GuiGetStyle(raygui.DEFAULT, raygui.BACKGROUND_COLOR);
        if (hex < 0) return ray.GRAY;
        return ray.GetColor(@intCast(hex));
    }

    //should be called before every iteration
    pub fn update(self: *@This()) void {
        self.active_x = (@This(){}).active_x;
        self.active_y = (@This(){}).active_y;

        if (self.style_changed) {
            self.style_changed = false;
            switch (selected_style) {
                0 => styles.GuiLoadStyleAmber(),
                1 => styles.GuiLoadStyleAshes(),
                2 => styles.GuiLoadStyleBluish(),
                3 => styles.GuiLoadStyleCandy(),
                4 => styles.GuiLoadStyleCherry(),
                5 => styles.GuiLoadStyleCyber(),
                6 => styles.GuiLoadStyleDark(),
                7 => styles.GuiLoadStyleEnefete(),
                8 => styles.GuiLoadStyleJungle(),
                9 => styles.GuiLoadStyleLavanda(),
                10 => styles.GuiLoadStyleSunny(),
                11 => styles.GuiLoadStyleTerminal(),
                else => {},
            }
        }
    }

    pub fn column(self: *@This()) void {
        self.active_x += self.widget_width + self.widget_padding;
        self.active_y = (@This(){}).active_y;
    }

    pub fn dropDownBox(self: *@This(), name: [:0]const u8, index: *usize, items: []const [:0]const u8) !void {
        var buffer: [1024]u8 = undefined;
        var i: usize = 0;
        for (items) |item| {
            for (item) |char| {
                buffer[i] = char;
                i += 1;
            }
            buffer[i] = ';';
            i += 1;
        }
        buffer[i] = 0;

        const mode = try self.dropdown_box_mode.getOrPut(name);
        if (!mode.found_existing) {
            mode.value_ptr.* = false;
        }
        const rect: raygui.Rectangle = .{
            .x = self.active_x,
            .y = self.active_y,
            .width = self.widget_width,
            .height = self.widget_height,
        };
        self.active_y += self.widget_height + self.widget_padding;

        var c_index: c_int = @intCast(index.*);
        const toggle_mode = raygui.GuiDropdownBox(rect, &buffer, &c_index, mode.value_ptr.*);
        if (toggle_mode == 1) {
            mode.value_ptr.* = !mode.value_ptr.*;
        }
        //update index
        index.* = @intCast(c_index);
    }

    ///names of the styles
    pub const StyleNames = [_][:0]const u8{ "amber", "ashes", "bluish", "candy", "cherry", "cyber", "dark", "enefete", "jungle", "lavanda", "sunny", "terminal" };

    pub fn guiStylePicker(self: *@This()) !void {
        const old_style = selected_style;
        try self.dropDownBox("guiStylePicker", &selected_style, &StyleNames);
        if (selected_style != old_style) {
            self.style_changed = true;
        }
    }

    pub fn button(self: *@This(), name: [:0]const u8) bool {
        const rect: raygui.Rectangle = .{
            .x = self.active_x,
            .y = self.active_y,
            .width = self.widget_width,
            .height = self.widget_height,
        };
        self.active_y += self.widget_height + self.widget_padding;
        const pressed = true; //ray.IsMouseButtonPressed(ray.MOUSE_BUTTON_LEFT);
        const button_down = raygui.GuiButton(rect, name);
        return (pressed and button_down == 1);
    }

    pub fn line(self: *@This()) void {
        const rect: raygui.Rectangle = .{
            .x = self.active_x,
            .y = self.active_y,
            .width = self.widget_width,
            .height = self.widget_height,
        };
        self.active_y += self.widget_height + self.widget_padding;

        _ = raygui.GuiLine(rect, null);
    }

    pub fn textBox(self: *@This(), name: [:0]const u8) ![:0]const u8 {
        const rect: raygui.Rectangle = .{
            .x = self.active_x,
            .y = self.active_y,
            .width = self.widget_width,
            .height = self.widget_height,
        };

        //fetch data
        const text = try self.text_box_text.getOrPut(name);
        if (!text.found_existing) {
            text.value_ptr.* = empty_buffer;
        }
        const mode = try self.text_box_mode.getOrPut(name);
        if (!mode.found_existing) {
            mode.value_ptr.* = false;
        }

        //draw textbox
        const clicked = raygui.GuiTextBox(rect, text.value_ptr, 32, mode.value_ptr.*);
        if (clicked == 1) {
            mode.value_ptr.* = !mode.value_ptr.*;
        }

        const label_rect: raygui.Rectangle = .{
            .x = self.active_x + self.widget_width + self.widget_padding,
            .y = self.active_y,
            .width = self.widget_width,
            .height = self.widget_height,
        };
        _ = raygui.GuiLabel(label_rect, name);

        //update manager
        self.active_y += self.widget_height + self.widget_padding;

        //return text box contents
        return std.mem.sliceTo(text.value_ptr, 0);
    }
};
