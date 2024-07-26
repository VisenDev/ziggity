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

    //defaults
    const default_padding = 16;
    const default_width = 150;

    ///gui layout data
    widget_padding: f32 = default_padding,
    text_size: c_int = 24,
    widget_width: f32 = default_width,
    widget_height: f32 = 24,
    active_x: f32 = default_padding, //coordinates to draw next widget at
    active_y: f32 = default_padding,
    active_scroll_id: ?[:0]const u8 = null, //id of active scroll
    next_column_extra_offset: f32 = 0, //how far over the next column will be

    /// data for widgets
    scroll_panel_scroll: std.StringHashMap(raygui.Vector2) = undefined,
    value_box_mode: std.StringHashMap(bool) = undefined,
    value_box_value: std.StringHashMap(c_int) = undefined,
    text_box_mode: std.StringHashMap(bool) = undefined,
    text_box_text: std.StringHashMap(StringBuffer) = undefined,
    dropdown_box_mode: std.StringHashMap(bool) = undefined,

    /// whether the styles have changed and need to be reloaded
    style_changed: bool = true,

    const StringBuffer = [256:0]u8;
    const empty_buffer: StringBuffer = .{0} ** 256;

    ///selected style index
    var selected_style: usize = 6;

    ///for making sure that buttons don't get pressed when you swap between windows
    var buttons_enabled: bool = true;
    var reenable_buttons: bool = false;

    pub fn init(a: std.mem.Allocator) @This() {
        return .{
            .scroll_panel_scroll = std.StringHashMap(raygui.Vector2).init(a),
            .value_box_mode = std.StringHashMap(bool).init(a),
            .value_box_value = std.StringHashMap(c_int).init(a),
            .text_box_mode = std.StringHashMap(bool).init(a),
            .text_box_text = std.StringHashMap(StringBuffer).init(a),
            .dropdown_box_mode = std.StringHashMap(bool).init(a),
        };
    }

    pub fn deinit(self: *@This()) void {
        self.value_box_mode.deinit();
        self.value_box_value.deinit();
        self.text_box_mode.deinit();
        self.text_box_text.deinit();
        self.dropdown_box_mode.deinit();

        self.endScrollPanel();
    }

    ///returns the proper background color for the ui styling
    pub fn backgroundColor(self: *const @This()) ray.Color {
        _ = self; // autofix
        const hex: c_int = raygui.GuiGetStyle(raygui.DEFAULT, raygui.BACKGROUND_COLOR);
        if (hex < 0) return ray.GRAY;
        return ray.GetColor(@intCast(hex));
    }

    //should be called before every iteration
    pub fn update(self: *@This()) void {

        //reenable buttons
        if (reenable_buttons) {
            buttons_enabled = true;
            reenable_buttons = false;
        }

        //check whether buttons should be reenabled
        if (!buttons_enabled and ray.IsMouseButtonUp(ray.MOUSE_BUTTON_LEFT)) {
            reenable_buttons = true;
        }

        //reset layout
        self.active_x = (@This(){}).active_x;
        self.active_y = (@This(){}).active_y;
        self.next_column_extra_offset = 0;
        self.widget_width = (@This(){}).widget_width;

        //update style
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

    pub fn startScrollPanel(self: *@This(), id: [:0]const u8, num_widgets_displayed: f32, num_widgets_provided: f32) !void {
        const display_rect: raygui.Rectangle = .{
            .x = self.active_x,
            .y = self.active_y,
            .width = self.widget_width * 2,
            .height = self.widget_height + (self.widget_height + self.widget_padding) * num_widgets_displayed,
        };

        //bounds of the content of the scroll bar
        const content_rect: raygui.Rectangle = .{
            .x = self.active_x,
            .y = self.active_y,
            .width = self.widget_width * 2 - self.widget_padding * 2,
            .height = self.widget_height + (self.widget_height + self.widget_padding) * num_widgets_provided,
        };

        // fetch scroll amount
        const scroll = try self.scroll_panel_scroll.getOrPut(id);
        if (!scroll.found_existing) {
            scroll.value_ptr.* = .{ .x = 0, .y = 0 };
        }

        var view = raygui.Rectangle{ .x = 0, .y = 0, .width = 0, .height = 0 };
        _ = raygui.GuiScrollPanel(display_rect, id, content_rect, scroll.value_ptr, &view);

        //begin scissor mode to cutoff unwanted bits of the contents
        raygui.BeginScissorMode(
            @intFromFloat(@floor(view.x)),
            @intFromFloat(@floor(view.y)),
            @intFromFloat(@floor(view.width * 2)),
            @intFromFloat(@floor(view.height)),
        );
        self.active_scroll_id = id;

        //update active_y
        self.active_y += self.widget_height + self.widget_padding;

        //update active_x so that scroll bar widgets are offset inside bar
        self.active_x += self.widget_padding;

        //update column_offset to accommodate larger scroll bar width
        self.next_column_extra_offset += self.widget_width;

        //set widgets future width to be in scroll var
        self.widget_width = (@This(){}).widget_width * 2 - self.widget_padding * 2;
    }

    pub fn endScrollPanel(self: *@This()) void {
        self.active_scroll_id = null;

        //undo updating active_x so that scroll bar widgets are offset inside bar
        self.active_x -= self.widget_padding;
        self.widget_width = (@This(){}).widget_width;
        raygui.EndScissorMode();
    }

    /// calculates bounds and updates gui layout, height_scalar multiplies how high the widget is from default
    pub fn calculateWidgetBounds(self: *const @This()) raygui.Rectangle {
        var y_offset: f32 = 0;
        if (self.active_scroll_id) |id| {
            y_offset = self.scroll_panel_scroll.get(id).?.y;
        }
        const rect: raygui.Rectangle = .{
            .x = self.active_x,
            .y = self.active_y + y_offset,
            .width = self.widget_width,
            .height = self.widget_height,
        };
        return rect;
    }

    pub fn repositionForNextWidget(self: *@This()) void {
        //update manager
        self.active_y += (self.widget_height) + self.widget_padding;
    }

    pub fn title(self: *@This(), text: [:0]const u8) void {
        const rect = self.calculateWidgetBounds();
        self.repositionForNextWidget();
        _ = raygui.GuiLabel(rect, text);
    }

    pub fn column(self: *@This()) void {
        self.active_x += self.widget_width + self.next_column_extra_offset + (self.widget_padding * 2);
        self.active_y = (@This(){}).active_y;
        self.next_column_extra_offset = (@This(){}).next_column_extra_offset;
        self.widget_width = (@This(){}).widget_width;

        const rect: raygui.Rectangle = .{
            .x = self.active_x - self.widget_padding,
            .y = -5,
            .width = @floatFromInt(ray.GetScreenWidth()),
            .height = @floatFromInt(ray.GetScreenHeight() * 2),
        };
        _ = raygui.GuiPanel(rect, null);
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

        const rect = self.calculateWidgetBounds();
        self.repositionForNextWidget();

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

    pub fn button(self: *@This(), id: [:0]const u8) bool {
        const rect = self.calculateWidgetBounds();
        self.repositionForNextWidget();
        const button_down = raygui.GuiButton(rect, id);
        const result = (buttons_enabled and button_down == 1);
        if (result) {
            buttons_enabled = false;
        }
        return result;
    }

    pub fn line(self: *@This()) void {
        const rect = self.calculateWidgetBounds();
        self.repositionForNextWidget();
        _ = raygui.GuiLine(rect, null);
    }

    pub fn textBox(self: *@This(), id: [:0]const u8) ![:0]const u8 {
        const rect = self.calculateWidgetBounds();
        self.repositionForNextWidget();

        //fetch data
        const text = try self.text_box_text.getOrPut(id);
        if (!text.found_existing) {
            text.value_ptr.* = empty_buffer;
        }
        const mode = try self.text_box_mode.getOrPut(id);
        if (!mode.found_existing) {
            mode.value_ptr.* = false;
        }

        //draw textbox
        const clicked = raygui.GuiTextBox(rect, text.value_ptr, 32, mode.value_ptr.*);
        if (clicked == 1) {
            mode.value_ptr.* = !mode.value_ptr.*;
        }

        //return text box contents
        return std.mem.sliceTo(text.value_ptr, 0);
    }

    pub fn valueBox(self: *@This(), comptime T: type, id: [:0]const u8) !T {
        const rect = self.calculateWidgetBounds();
        self.repositionForNextWidget();

        //fetch data
        const value = try self.value_box_value.getOrPut(id);
        if (!value.found_existing) {
            value.value_ptr.* = 0;
        }
        const mode = try self.value_box_mode.getOrPut(id);
        if (!mode.found_existing) {
            mode.value_ptr.* = false;
        }

        //draw textbox
        const clicked = raygui.GuiValueBox(
            rect,
            id,
            value.value_ptr,
            @max(std.math.minInt(T), std.math.minInt(c_int)),
            @min(std.math.maxInt(T), std.math.maxInt(c_int)),
            mode.value_ptr.*,
        );
        if (clicked == 1) {
            mode.value_ptr.* = !mode.value_ptr.*;
        }

        //return text box contents
        return @intCast(value.value_ptr.*);
    }
};
