const std = @import("std");
const glfw = @import("glfw");
const core = @import("core.zig");
const za = @import("zalgebra");

const Input = @import("Input.zig");
const Bounds = @import("Bounds.zig");

const Self = @This();

var glfw_initialized: bool = false;

const log = std.log.scoped(.window);

pub const Info = struct {
    title: [:0]const u8,
    width: u32,
    height: u32,
    proj: za.Mat4,
};

pub const WindowParams = struct {
    title: [:0]const u8,
    width: u32,
    height: u32,
    current: bool = true,
    resizable: bool = false,
};

info: *Info,
handle: *glfw.Window,
allocator: std.mem.Allocator,

fn calcProj(width: u32, height: u32) za.Mat4 {
    const fwidth: f32 = @floatFromInt(width);
    const fheight: f32 = @floatFromInt(height);
    return za.Mat4.orthographic(-fwidth / 2, fwidth / 2, -fheight / 2, fheight / 2, -1, 1);
}

fn glfwErrorCallback(error_code: glfw.ErrorCode, description: [*:0]const u8) callconv(.C) void {
    log.err("GLFW error ({d}): {s}", .{ error_code, description });
}

fn glfwInit() !void {
    if (glfw_initialized) return;
    try glfw.init();
    glfw.windowHint(glfw.ContextVersionMajor, 4);
    glfw.windowHint(glfw.ContextVersionMinor, 6);
    glfw.windowHint(glfw.OpenGLProfile, glfw.OpenGLCoreProfile);
    _ = glfw.setErrorCallback(&glfwErrorCallback);

    glfw_initialized = true;
}

pub fn init(allocator: std.mem.Allocator, params: WindowParams) !Self {
    try glfwInit();

    glfw.windowHint(glfw.Resizable, @intFromBool(params.resizable));

    const handle = try glfw.createWindow(@intCast(params.width), @intCast(params.height), params.title, null, null);
    if (params.current) glfw.makeContextCurrent(handle);

    const info = try allocator.create(Info);
    info.* = .{
        .title = params.title,
        .width = params.width,
        .height = params.height,
        .proj = calcProj(@intCast(params.width), @intCast(params.height)),
    };

    glfw.setWindowUserPointer(handle, info);
    _ = glfw.setFramebufferSizeCallback(handle, &framebufferSizeCallback);
    return Self{
        .info = info,
        .handle = handle,
        .allocator = allocator,
    };
}

pub fn makeCurrent(self: Self) void {
    glfw.makeContextCurrent(self.handle);
}

pub fn getProj(self: Self) *const za.Mat4 {
    return &self.info.proj;
}

pub fn input(self: Self) Input {
    return Input{ .handle = self.handle };
}

pub fn deinit(self: Self) void {
    glfw.destroyWindow(self.handle);
    self.allocator.destroy(self.info);
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

pub fn getBounds(self: Self) Bounds {
    return Bounds.init(0.0, 0.0, @floatFromInt(self.info.width), @floatFromInt(self.info.height));
}

const FrameBufferSizeFn = *const fn (width: u32, height: u32) void;
var frameBufferSize_callback: ?FrameBufferSizeFn = null;

pub fn registerFrameBufferSizeCallback(cb: FrameBufferSizeFn) void {
    frameBufferSize_callback = cb;
}

fn framebufferSizeCallback(window: *glfw.Window, width: i32, height: i32) callconv(.c) void {
    const maybe_ptr = glfw.getWindowUserPointer(window);
    if (maybe_ptr) |ptr| {
        const info: *Info = @ptrCast(@alignCast(ptr));
        info.width = @intCast(width);
        info.height = @intCast(height);

        info.proj = calcProj(info.width, info.height);
    } else {
        log.warn("Window user pointer is null", .{});
    }

    if (frameBufferSize_callback) |cb| {
        cb(@intCast(width), @intCast(height));
    }
}
