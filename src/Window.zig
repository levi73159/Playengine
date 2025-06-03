const std = @import("std");
const glfw = @import("glfw");
const core = @import("core.zig");

const Self = @This();

title: []const u8,
width: u32,
height: u32,
handle: *glfw.Window,

pub fn init(title: []const u8, width: u32, height: u32, current: bool) !Self {
    const handle = try glfw.createWindow(width, height, title, null, null);
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
