const std = @import("std");
const gl = @import("gl");
const Layout = @import("BufferLayout.zig");
const ArrayBuffer = @import("ArrayBuffer.zig");

const Self = @This();

var id_bound: u32 = 0;

id: u32,
layout: Layout,

// the Vertex Array owns the layout
pub fn init(layout: Layout) Self {
    var id: u32 = undefined;
    gl.GenVertexArrays(1, @ptrCast(&id));
    return Self{
        .id = id,
        .layout = layout,
    };
}

pub fn deinit(self: *Self) void {
    self.layout.deinit();
    gl.DeleteVertexArrays(1, @ptrCast(&self.id));
}

pub fn bind(self: Self) void {
    if (id_bound == self.id) return;
    gl.BindVertexArray(self.id);
    id_bound = self.id;
}

pub fn addBuffer(self: Self, buffer: ArrayBuffer) void {
    self.bind();
    buffer.bind();

    var offset: u32 = 0;
    for (self.layout.elements.items, 0..) |elem, i| {
        gl.EnableVertexAttribArray(@intCast(i));
        gl.VertexAttribPointer(@intCast(i), @intCast(elem.count), @intFromEnum(elem.ty), @intFromBool(elem.normalized), @intCast(self.layout.stride), offset);

        offset += elem.ty.size() * elem.count;
    }
}

pub fn unbind() void {
    if (id_bound == 0) return;
    gl.BindVertexArray(0);
    id_bound = 0;
}
