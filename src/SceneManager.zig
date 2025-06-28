const std = @import("std");
const Scene = @import("Scene.zig");
const Window = @import("Window.zig");
const Camera = @import("Camera.zig");
const Engine = @import("Engine.zig");
const renderer = @import("renderer.zig");

const Self = @This();

scenes: []const Scene,
current_index: usize = 0,
window: *const Window,

pub fn init(scenes: []const Scene, window: *const Window) Self {
    return Self{
        .scenes = scenes,
        .window = window,
    };
}

pub fn deinit(self: Self, allocator: std.mem.Allocator) void {
    for (self.scenes) |s| {
        s.deinit(allocator);
    }
}

pub fn loadWithoutUnload(self: *Self, index: usize) anyerror!void {
    self.current_index = index;
    try self.scenes[index].load(self.window, &Engine.getCurrent().camera);
}

pub fn load(self: *Self, index: usize) anyerror!void {
    try self.unload(); // unload current scene
    return self.loadWithoutUnload(index);
}

pub fn loadByName(self: *Self, name: []const u8) anyerror!void {
    for (self.scenes, 0..) |s, i| {
        if (std.mem.eql(u8, s.name, name)) {
            self.current_index = i;
            return self.load(i);
        }
    }
    std.log.err("Scene {s} not found", .{name});
    return error.SceneNotFound;
}

pub fn unload(self: Self) anyerror!void {
    try self.scenes[self.current_index].unload(self.window, &Engine.getCurrent().camera); // unload current scene
}

pub fn get(self: *const Self, index: usize) *const Scene {
    return &self.scenes[index];
}

pub fn getByName(self: *const Self, name: []const u8) ?*const Scene {
    for (self.scenes) |s| {
        if (std.mem.eql(u8, s.name, name)) {
            return &s;
        }
    }
    return null;
}

pub fn getCurrent(self: *const Self) *const Scene {
    return &self.scenes[self.current_index];
}

pub fn getCurrentMut(self: *Self) *Scene {
    return &self.scenes[self.current_index];
}
