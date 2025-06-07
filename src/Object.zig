const std = @import("std");
const buf = @import("buffer.zig");
const Bounds = @import("Bounds.zig");
const renderer = @import("renderer.zig");

const Transform = @import("Transform.zig");

const Self = @This();

id: u32,
vertex_buffer: buf.ArrayBuffer,
index_buffer: buf.IndexBuffer,
transform: Transform,

pub fn deinit(self: *const Self) void {
    self.vertex_buffer.deinit();
    self.index_buffer.deinit();
}

pub fn getBounds(self: *const Self) Bounds {
    return Bounds.fromTransform(self.transform);
}

pub inline fn createSquare() !Self {
    return renderer.createSquare(); // this is a renderer function but best accessed from here
}

pub inline fn createBasicSquare() !Self {
    return renderer.createBasicSquare(); // this is a renderer function but best accessed from here
}
