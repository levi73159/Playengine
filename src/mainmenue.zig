const std = @import("std");
const za = @import("zalgebra");
const Window = @import("Window.zig");
const Object = @import("Object.zig");
const assets = @import("assets_manager.zig");
const Color = @import("Color.zig");
const Camera = @import("Camera.zig");
const Scene = @import("Scene.zig");
const Texture = @import("Texture.zig");
const renderer = @import("renderer.zig");
const Engine = @import("Engine.zig");
const Input = @import("Input.zig");
const Rect = @import("bounds.zig").RectBounds;

const Template = @import("rendererObjects.zig").RenderObjectTemplate;

const Self = @This();

background: *Texture = undefined,
startbtn_texture: *Texture = undefined,
exitbtn_texture: *Texture = undefined,

start_bounds: Rect = Rect.zero(),
exit_bounds: Rect = Rect.zero(),

mouse_hover: bool = false,
mouse_pressed: bool = false,
mouse_hold: bool = false,

pub fn getTemplates(allocator: std.mem.Allocator, window: *const Window) []const Template {
    const wb = window.getBounds();
    std.log.debug("Window bounds: {d}x{d}", .{ wb.width, wb.height });
    const templates = [_]Template{
        Template{
            .name = "Background",
            .object_type = .textured_square,
            .texture = "MenuBackgroundTexture",
            .color = Color.white,
            .zindex = -10,
            .transform = .{ .scale = za.Vec2.new(wb.width, wb.height) },
        },
        Template{
            .name = "StartButton",
            .object_type = .textured_square,
            .texture = "StartButtonTexture",
            .color = Color.white,
            .zindex = 0,
        },
        Template{
            .name = "ExitButton",
            .object_type = .textured_square,
            .texture = "ExitButtonTexture",
            .color = Color.white,
            .zindex = 0,
        },
    };

    return allocator.dupe(Template, &templates) catch unreachable;
}

pub fn load(self: *Self, _: Scene, _: *const Window, _: *Camera) anyerror!void {
    self.background = try assets.loadTexture("MenuBackgroundTexture", "res/sprites/menu_background.png", 0);
    self.startbtn_texture = try assets.loadTexture("StartButtonTexture", "res/sprites/start_button.png", 1);
    self.exitbtn_texture = try assets.loadTexture("ExitButtonTexture", "res/sprites/exit_button.png", 2);
}

pub fn unload(self: *Self, _: Scene, _: *const Window, _: *Camera) anyerror!void {
    assets.unloadTexture(self.background);
    assets.unloadTexture(self.startbtn_texture);
    assets.unloadTexture(self.exitbtn_texture);
}

pub fn start(self: *Self, _: Scene, w: *const Window, _: *Camera) anyerror!void {
    renderer.setClearColor(Color.black);

    const start_button = (renderer.findObject("StartButton") orelse return error.NotFound).object;
    const exit_button = (renderer.findObject("ExitButton") orelse return error.NotFound).object;
    const background = (renderer.findObject("Background") orelse return error.NotFound).object;

    start_button.transform.scale = self.startbtn_texture.size().scale(0.5);
    exit_button.transform.scale = self.exitbtn_texture.size().scale(0.5);

    background.transform.scale = w.getBounds().size();

    start_button.transform.pos = za.Vec2.zero();
    exit_button.transform.pos = za.Vec2.new(0, -self.startbtn_texture.size().y() / 2.0 * 1.2);

    self.start_bounds = start_button.getBounds();
    self.exit_bounds = exit_button.getBounds();
}

pub fn update(self: *Self, _: Scene, window: *const Window, _: *Camera, input: *Input) anyerror!void {
    const screenspace_mousepos = input.getMousePos();
    const mouse_pos = window.screenToWorld(screenspace_mousepos);

    // hover logic for mouse cursor
    const is_hover = self.start_bounds.contains(mouse_pos) or self.exit_bounds.contains(mouse_pos);
    if (is_hover and !self.mouse_hover) {
        input.setCursorShape(.hand);
        self.mouse_hover = true;
    } else if (!is_hover and self.mouse_hover) {
        input.setCursorShape(.arrow);
        self.mouse_hover = false;
    }

    // mouse press logic
    if (input.getMousePress(.left) and !self.mouse_hold) {
        self.mouse_hold = true;
        self.mouse_pressed = true;
    } else if (!input.getMousePress(.left)) {
        self.mouse_hold = false;
        self.mouse_pressed = false;
    } else {
        self.mouse_pressed = false;
    }

    if (self.start_bounds.contains(mouse_pos) and self.mouse_pressed) {
        input.setCursorShape(.default);
        try Engine.sceneManager().load(1);
    } else if (self.exit_bounds.contains(mouse_pos) and self.mouse_pressed) {
        input.setCursorShape(.default);
        Engine.close();
    }
}
