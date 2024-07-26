const anime = @import("animation.zig");
const std = @import("std");
const ray = @cImport({
    @cInclude("raylib.h");
});

const raygui = @cImport({
    @cInclude("raygui.h");
    @cInclude("style_dark.h");
});

pub const RayGuiManager = struct {
    widget_padding: f32 = 10,
    text_size: c_int = 15,
    widget_width: f32 = 150,
    widget_height: f32 = 30,
    active_x: f32 = 10,
    active_y: f32 = 10,

    text_box_index: usize = 0,
    text_box_mode: std.StringHashMap(bool) = undefined,
    text_box_text: std.StringHashMap(StringBuffer) = undefined,

    const StringBuffer = [256:0]u8;
    const empty_buffer: StringBuffer = .{0} ** 256;

    pub fn init(a: std.mem.Allocator) @This() {
        return .{
            .text_box_mode = std.StringHashMap(bool).init(a),
            .text_box_text = std.StringHashMap(StringBuffer).init(a),
        };
    }

    pub fn deinit(self: *@This()) void {
        self.text_box_mode.deinit();
        self.text_box_text.deinit();
    }

    //should be called before every iteration
    pub fn update(self: *@This()) void {
        self.active_x = (@This(){}).active_x;
        self.active_y = (@This(){}).active_y;
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
