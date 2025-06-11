const std = @import("std");
const buf = @import("buffer.zig");
const Rect = @import("bounds.zig").RectBounds;
const renderer = @import("renderer.zig");
const Shader = @import("Shader.zig");
const za = @import("zalgebra");
const Color = @import("Color.zig");
const Texture = @import("Texture.zig");

const Transform = @import("Transform.zig");

const Self = @This();

const MoveData = struct {
    speed: f32,
    direction: za.Vec2,
};

const DataType = union(enum) {
    move_data: MoveData,
};

name: []const u8,
id: u32, // vertex_array index
vertex_buffer: buf.ArrayBuffer, // owns this (if not static)
index_buffer: buf.IndexBuffer, // owns this
shader: *Shader, // do not own this, it is owned by the renderer and should not be deinitialized

// uniforms
transform: Transform = .{},
color: Color = Color.white,
texture: ?*Texture = null, // not owned
texture_slot: ?u32 = null, // only used if texture is not null
uniforms: std.StringArrayHashMapUnmanaged(Shader.UniformValue) = .{},
allocator: std.mem.Allocator,

// render state
static: bool = false, // whether the object is owned by the renderer or owned by someone else
zindex: u32 = 0,
visible: bool = true,

data: ?DataType = null, // extra data for the object

pub fn deinit(self: *Self) void {
    self.uniforms.deinit(self.allocator);

    if (self.static) return; // owned by the renderer
    self.vertex_buffer.deinit();
    self.index_buffer.deinit();
}

// return the rect bounds
pub fn getBounds(self: *const Self) Rect {
    return Rect.fromTransform(self.transform);
}

pub inline fn createSquare(name: []const u8, shader: *Shader) !*Self {
    return renderer.createSquare(name, shader); // this is a renderer function but best accessed from here
}

pub inline fn createBasicSquare(name: []const u8, shader: *Shader) !*Self {
    return renderer.createBasicSquare(name, shader); // this is a renderer function but best accessed from here
}

pub inline fn overlaps(self: Self, other: Self) bool {
    return self.getBounds().overlaps(other.getBounds());
}

pub fn setUnifrom(self: *Self, name: []const u8, value: Shader.UniformValue) !void {
    try self.uniforms.put(self.allocator, name, value);
}

// does not clone the buffers
pub fn clone(self: Self) !Self {
    return Self{
        .name = self.name,
        .id = self.id,
        .vertex_buffer = self.vertex_buffer,
        .index_buffer = self.index_buffer,
        .shader = self.shader,
        .transform = self.transform,
        .color = self.color,
        .texture = self.texture,
        .texture_slot = self.texture_slot,
        .uniforms = try self.uniforms.clone(self.allocator),
        .allocator = self.allocator,
        .static = self.static,
        .zindex = self.zindex,
        .visible = self.visible,
    };
}
