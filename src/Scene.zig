const std = @import("std");
const builtin = @import("builtin");
const Window = @import("Window.zig");
const Camera = @import("Camera.zig");
const renderer = @import("renderer.zig");
const time = @import("time.zig");
const Input = @import("Input.zig");

const RenderObjectTemplate = @import("rendererObjects.zig").RenderObjectTemplate;

const Self = @This();
const suppress_saftey_checks_warning = false;

const Callback = fn (self: *anyopaque, scene: Self, w: *const Window, c: *Camera) anyerror!void;
const InputCallback = fn (self: *anyopaque, scene: Self, w: *const Window, c: *Camera, input: *Input) anyerror!void;

name: []const u8,
objects: []const RenderObjectTemplate, // array of render object templates to create when scene is loaded

context: *anyopaque = undefined, // user context with functions
context_size: usize = 0,
context_alignment: usize = 0,

// order of events
// on_load -> make objects -> on_start -> (loop) -> on_update -> on_render (end loop) -> on_unload
on_load: ?*const Callback = null,
on_unload: ?*const Callback = null,

on_start: ?*const Callback = null,

on_update: ?*const InputCallback = null,
on_render: ?*const Callback = null,

pub fn init(name: []const u8, objects: []const RenderObjectTemplate) Self {
    return Self{
        .name = name,
        .objects = objects,
    };
}

pub fn deinit(self: Self, allocator: std.mem.Allocator) void {
    if (self.context_size == 0) return; // nothing to free

    const rawMemory: [*]u8 = @ptrCast(self.context);
    const memory = rawMemory[0..self.context_size];
    allocator.rawFree(memory, .fromByteUnits(self.context_alignment), @returnAddress());

    allocator.free(self.objects);
}

pub fn initFromType(comptime T: type, allocator: std.mem.Allocator) Self {
    const name = @typeName(T);

    const objects: []const RenderObjectTemplate = blk: {
        if (@hasDecl(T, "getTemplates")) {
            break :blk T.getTemplates(allocator, renderer.getDefaultWindow());
        } else {
            std.log.warn("Scene {s} has no getTemplates function, returning empty array", .{name});
            break :blk &[_]RenderObjectTemplate{};
        }
    };

    var self = Self{
        .name = name,
        .objects = objects,
    };

    self.setContext(T, allocator);
    return self;
}

/// initialize callbacks and context with type
pub fn setContext(self: *Self, comptime T: type, allocator: std.mem.Allocator) void {
    self.setField(T, Callback, "on_load", "load");
    self.setField(T, Callback, "on_unload", "unload");
    self.setField(T, Callback, "on_start", "start");
    self.setField(T, InputCallback, "on_update", "update");
    self.setField(T, Callback, "on_render", "render");

    // initialize context T
    const ptr = allocator.create(T) catch unreachable;
    ptr.* = T{};

    self.context = ptr;
    self.context_size = @sizeOf(T);
    self.context_alignment = @alignOf(T);
}

inline fn setField(self: *Self, comptime Context: type, comptime SafteyCheckType: type, comptime name: []const u8, comptime other_name: []const u8) void {
    if (@hasDecl(Context, other_name)) {
        if (safteyCheck(Context, @TypeOf(@field(Context, other_name)), SafteyCheckType)) {
            @field(self, name) = @ptrCast(&@field(Context, other_name));
        }
    }
}

fn safteyCheck(comptime _: type, comptime T1: type, comptime T2: type) bool {
    if (builtin.mode == .ReleaseFast or builtin.mode == .ReleaseSmall) return true; // no saftey checks on smal or fast release

    const info = @typeInfo(T1);
    const otherinfo = @typeInfo(T2);

    if (info != .@"fn") return false;
    if (info.@"fn".params.len != otherinfo.@"fn".params.len) {
        if (!suppress_saftey_checks_warning) {
            std.log.err("function {s} does not have the same number of parameters as Callback", .{@typeName(T1)});
        }
        return false;
    }
    if (info.@"fn".return_type != otherinfo.@"fn".return_type) {
        if (!suppress_saftey_checks_warning) {
            std.log.err("function {s} does not have the same return type as Callback", .{@typeName(T1)});
        }
        return false;
    }
    // since this is slow we only wanna do this in debug mode
    if (builtin.mode == .Debug) {
        inline for (info.@"fn".params[1..], otherinfo.@"fn".params[1..]) |param, other| {
            if (param.type != other.type) {
                if (!suppress_saftey_checks_warning) {
                    std.log.err("function {s} does not have the same parameter types as Callback", .{@typeName(T1)});
                }
                return false;
            }
        }
    }

    return true;
}

// will be called when the scene is loaded
pub fn load(self: Self, window: *const Window, camera: *Camera) anyerror!void {
    // load textures and stuff needed
    if (self.on_load) |f| {
        try f(self.context, self, window, camera);
    }

    // make the objects
    for (self.objects) |o| {
        _ = try o.make();
    }

    if (self.on_start) |f| {
        try f(self.context, self, window, camera);
    }
}

pub fn unload(self: Self, window: *const Window, camera: *Camera) anyerror!void {
    if (self.on_unload) |f| {
        try f(self.context, self, window, camera);
    }

    renderer.destroyAll(); // destroy all objects in the scene
}

pub fn update(self: Self, window: *const Window, camera: *Camera, input: *Input) anyerror!void {
    if (self.on_update) |f| {
        try f(self.context, self, window, camera, input);
    }
}

pub fn render(self: Self, window: *const Window, camera: *Camera) anyerror!void {
    if (self.on_render) |f| {
        try f(self.context, self, window, camera);
    }
}
