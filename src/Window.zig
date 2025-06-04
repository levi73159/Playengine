const std = @import("std");
const glfw = @import("glfw");
const core = @import("core.zig");

const Self = @This();

var glfw_initialized: bool = false;

title: [:0]const u8,
width: u32,
height: u32,
handle: *glfw.Window,

fn glfwInit() !void {
    if (glfw_initialized) return;
    try glfw.init();
    glfw.windowHint(glfw.ContextVersionMajor, 4);
    glfw.windowHint(glfw.ContextVersionMinor, 6);
    glfw.windowHint(glfw.OpenGLProfile, glfw.OpenGLCoreProfile);

    glfw.windowHint(glfw.Resizable, 0);

    glfw_initialized = true;
}

pub fn init(title: [:0]const u8, width: u32, height: u32, current: bool) !Self {
    try glfwInit();

    const handle = try glfw.createWindow(@intCast(width), @intCast(height), title, null, null);
    if (current) glfw.makeContextCurrent(handle);

    try core.initOpenGL();
    return Self{
        .title = title,
        .width = width,
        .height = height,
        .handle = handle,
    };
}

pub fn makeCurrent(self: Self) void {
    glfw.makeContextCurrent(self.handle);
}

pub fn deinit(self: Self) void {
    glfw.destroyWindow(self.handle);
}

pub fn shouldClose(self: Self) bool {
    return glfw.windowShouldClose(self.handle);
}

pub fn pollEvents() void {
    glfw.pollEvents();
}

pub fn swapBuffers(self: Self) void {
    glfw.swapBuffers(self.handle);
}

pub fn setShouldClose(self: Self, value: bool) void {
    glfw.setWindowShouldClose(self.handle, value);
}
