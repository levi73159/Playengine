const std = @import("std");
const Window = @import("Window.zig");
const Input = @import("Input.zig");
const SceneManager = @import("SceneManager.zig");
const Camera = @import("Camera.zig");
const Color = @import("Color.zig");
const assets = @import("assets_manager.zig");
const random = @import("random.zig");

const glfw = @import("glfw");
const renderer = @import("renderer.zig");

const time = @import("time.zig");
const TimeStamp = @import("time.zig").TimeStamp;

const Scene = @import("Scene.zig");

const Self = @This();

const log = std.log.scoped(.Engine);

var current: ?*Self = null;

window: *const Window,
input: Input,
camera: Camera,
running: bool = false,

// managers
scene_manager: ?SceneManager = null,

// callbacks
on_start: ?*const fn (engine: *const Self) anyerror!void = null,
on_update: ?*const fn (engine: *const Self, stamp: TimeStamp) anyerror!void = null,
on_render: ?*const fn (engine: *const Self, stamp: TimeStamp) anyerror!void = null,
on_end: ?*const fn (engine: *const Self) anyerror!void = null,

pub fn init(window: *const Window) Self {
    Window.registerWindowCloseCallback(&onWindowClose);

    renderer.init(window) catch |err| {
        log.err("Failed to init renderer: {}", .{err});
        std.process.exit(0);
    };

    random.init();

    return Self{
        .window = window,
        .input = window.input(),
        .camera = Camera{},
    };
}

pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
    if (self.scene_manager) |sm| sm.deinit(allocator);

    renderer.deinit();
    renderer.deinitResources();
}

pub fn startSceneManager(self: *Self, scenes: []const Scene) void {
    self.scene_manager = SceneManager.init(scenes, self.window);
}

pub fn makeCurrent(self: *Self) void {
    current = self;
}

pub fn clearCurrent() void {
    current = null;
}

pub fn getInput(self: *Self) *Input {
    return &self.input;
}

pub fn getCurrent() *Self {
    if (current == null) @panic("No current engine");
    return current.?;
}

fn isManagersInitalized(self: *const Self) bool {
    return self.scene_manager != null;
}

pub fn getSceneManager(self: *Self) *SceneManager {
    return self.scene_manager.?;
}

fn preloadShaders() !void {
    // preload the shaders needed
    log.debug("Preloading Shaders", .{});
    // 3 builtin shaders
    try assets.preloadShader("TexturedShader", "shaders/textured"); // textured is the default
    try assets.preloadShader("ColoredShader", "shaders/colored");
    try assets.preloadShader("TextShader", "shaders/text");
}

fn isErrorFatal(err: anyerror) bool {
    return switch (err) {
        error.Fatal,
        error.FatalError,
        error.OutOfMemory,
        error.OutOfResources,
        error.AccessDenied,
        error.Unexpected,
        error.Unsupported,
        error.Unhandled,
        error.GLInternalError,
        error.GLInitFailed,
        error.InitFailed,
        => true,
        else => false,
    };
}

fn handleError(self: *Self, comptime Void: bool, err: anyerror) if (Void) void else noreturn {
    const is_fatal = isErrorFatal(err);
    log.err("{s}Error occured in engine: {s}!", .{ if (is_fatal) "FATAL " else "", @errorName(err) });

    if (is_fatal) std.process.exit(255);
    if (!Void) std.process.exit(1);

    if (self.running) {
        self.running = false;
    } else {
        std.process.exit(1);
    }
}

fn isVoid(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .error_union => |eu| eu.error_set == void,
        else => @TypeOf(T) == void,
    };
}

fn handleResult(self: *Self, result: anytype) switch (@typeInfo(@TypeOf(result))) {
    .error_union => |eu| eu.payload,
    else => @TypeOf(result),
} {
    return result catch |err| self.handleError(isVoid(@TypeOf(result)), err);
}

pub fn run(self: *Self) void {
    self.makeCurrent();

    assets.init(self.window.allocator);
    defer assets.deinit();

    self.handleResult(preloadShaders());

    if (self.on_start) |f| self.handleResult(f(self));
    defer if (self.on_end) |f| self.handleResult(f(self));

    if (self.scene_manager) |*sm| {
        self.handleResult(sm.loadWithoutUnload(0));
    }
    defer if (self.scene_manager) |*sm| self.handleResult(sm.unload());

    self.running = true;
    while (self.running) {
        Window.pollEvents();
        time.startFrame();

        renderer.clearDefault();
        const stamp = time.getStamp();

        if (self.on_update) |f| self.handleResult(f(self, stamp));
        if (self.scene_manager) |*sm| {
            self.handleResult(sm.getCurrent().update(self.window, &self.camera, &self.input));
        }
        if (self.on_render) |f| self.handleResult(f(self, stamp));
        if (self.scene_manager) |*sm| {
            self.handleResult(sm.getCurrent().render(self.window, &self.camera));
        }

        self.handleResult(renderer.renderAll(self.camera)); // render all objects in the scene

        self.window.swapBuffers();
    }
    self.running = false;
    self.window.setShouldClose(true);
}

// callback functions for window
pub fn onWindowClose() void {
    current.?.running = false;
}

pub fn close() void {
    current.?.running = false;
    current.?.window.setShouldClose(true);
}

pub fn maybeSceneManager() ?*SceneManager {
    if (current) |e| return &(e.scene_manager orelse return null);
    return null;
}

pub fn sceneManager() *SceneManager {
    return maybeSceneManager() orelse @panic("No scene manager");
}
