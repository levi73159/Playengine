const std = @import("std");
const glfw = @import("glfw");
const core = @import("core.zig");
const za = @import("zalgebra");

const Input = @import("Input.zig");
const Rect = @import("bounds.zig").RectBounds;

const Self = @This();

var glfw_initialized: bool = false;

const log = std.log.scoped(.window);

pub const Size = struct {
    width: u32,
    height: u32,
};

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
expected_size: Size,

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

    glfw.defaultWindowHints();
    glfw.windowHint(glfw.ContextVersionMajor, 4);
    glfw.windowHint(glfw.ContextVersionMinor, 6);
    glfw.windowHint(glfw.OpenGLProfile, glfw.OpenGLCoreProfile);
    glfw.windowHint(glfw.Samples, 32); // MSAA

    _ = glfw.setErrorCallback(&glfwErrorCallback);

    glfw_initialized = true;
}

pub fn init(allocator: std.mem.Allocator, params: WindowParams) !Self {
    try glfwInit();

    glfw.windowHint(glfw.Resizable, @intFromBool(params.resizable));
    const monitor = glfw.getPrimaryMonitor();

    const handle = try glfw.createWindow(@intCast(params.width), @intCast(params.height), params.title, monitor, null);
    if (params.current) glfw.makeContextCurrent(handle);

    var width: i32 = undefined;
    var height: i32 = undefined;
    glfw.getMonitorWorkarea(monitor, null, null, &width, &height);

    const info = try allocator.create(Info);
    info.* = .{
        .title = params.title,
        .width = @intCast(width),
        .height = @intCast(height),
        .proj = calcProj(@intCast(width), @intCast(height)),
    };

    glfw.setWindowUserPointer(handle, info);
    _ = glfw.setFramebufferSizeCallback(handle, &framebufferSizeCallback);
    _ = glfw.setWindowCloseCallback(handle, &windowCloseCallback);

    return Self{
        .info = info,
        .handle = handle,
        .allocator = allocator,
        .expected_size = .{
            .width = params.width,
            .height = params.height,
        },
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

pub fn getBounds(self: Self) Rect {
    return Rect.init(0.0, 0.0, @floatFromInt(self.info.width), @floatFromInt(self.info.height));
}

pub fn getFrameBufferSize(self: Self) Size {
    var fb_width: i32 = 0;
    var fb_height: i32 = 0;
    glfw.getFramebufferSize(self.handle, &fb_width, &fb_height);
    return Size{ .width = @intCast(fb_width), .height = @intCast(fb_height) };
}

pub fn getDrawableBounds(self: Self) Rect {
    const fb = self.getFrameBufferSize();
    return Rect.init(0.0, 0.0, @floatFromInt(fb.width), @floatFromInt(fb.height));
}

const FrameBufferSizeFn = *const fn (width: u32, height: u32) void;
var frameBufferSize_callback: ?FrameBufferSizeFn = null;

const OnCloseFn = *const fn () void;
var onClose_callback: ?*const fn () void = null;

pub fn registerFrameBufferSizeCallback(cb: FrameBufferSizeFn) void {
    frameBufferSize_callback = cb;
}

pub fn registerWindowCloseCallback(cb: OnCloseFn) void {
    onClose_callback = cb;
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

fn windowCloseCallback(_: *glfw.Window) callconv(.c) void {
    if (onClose_callback) |cb| {
        cb();
    }
}

pub fn screenToWorld(self: Self, vec: za.Vec2) za.Vec2 {
    // convert screen (orgin at top left) to world (origin in center)
    // need to flip y because +y is up and -y is down in the game engine but in windows +y is down because of the origin
    // to convert this we subtract the vector by half the width and height
    // then we flip the y by multiplying by (1, -1) to flip y
    const fwidth: f32 = @floatFromInt(self.info.width);
    const fheight: f32 = @floatFromInt(self.info.height);
    const unflipped = vec.sub(za.Vec2.new(fwidth / 2.0, fheight / 2.0));

    return unflipped.mul(za.Vec2.new(1.0, -1.0)); // flip y
}
