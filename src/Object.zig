const std = @import("std");
const buf = @import("buffer.zig");

const Self = @This();

vertex_array: buf.VertexArray,
vertex_buffer: buf.ArrayBuffer,
index_buffer: buf.IndexBuffer,

pub fn deinit(self: *const Self) void {
    self.vertex_buffer.deinit();
    self.index_buffer.deinit();
}
