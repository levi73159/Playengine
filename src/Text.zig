const std = @import("std");
const gl = @import("gl");

const Font = @import("Font.zig");
const Transform = @import("Transform.zig");
const Color = @import("Color.zig");
const Shader = @import("Shader.zig");
const buf = @import("buffer.zig");
const Camera = @import("Camera.zig");

const Self = @This();

pub const Text_TextureSlot = 3; // the text texture is bound to texture slot 3 by default
pub const buffer_len = 6 * 4;
pub const buffer_size = @sizeOf(f32) * buffer_len;

// shared resources
// these are created when the first text is created
var shared_buffer: ?buf.ArrayBuffer = null;
var shared_vao: ?buf.VertexArray = null;

name: []const u8,
text: []const u8,
font: *const Font,
shader: *Shader,

scale: f32 = 1.0,
transform: Transform = .{},
color: Color = Color.white,

world_space: bool = false, // true if the text is in world space (will use camera matrix)
zindex: u32 = 0, // only used if world_space is true
visible: bool = true,

pub fn deinitResources() void {
    if (shared_vao) |*vao| vao.deinit();
    if (shared_buffer) |*buffer| buffer.deinit();
}

pub fn canBeRendered(self: Self) bool {
    return self.visible and self.text.len > 0;
}

pub fn getReadyForRendering() !void {
    if (shared_buffer == null) {
        shared_buffer = buf.ArrayBuffer.initEmpty(buffer_size, .dynamic);
        shared_vao = buf.VertexArray.init(try buf.BufferLayout.init(buf.BufferLayout.texcords_layout));

        shared_vao.?.bindBuffer(shared_buffer.?);
    }

    gl.ActiveTexture(gl.TEXTURE0 + Text_TextureSlot);
    shared_vao.?.bind();
    shared_buffer.?.bind();
}

pub fn getBuffer() *buf.ArrayBuffer {
    return &shared_buffer.?;
}

pub inline fn create(name: []const u8, text: []const u8, shader: *Shader, font: *const Font) !*Self {
    return @import("renderer.zig").createText(name, text, shader, font);
}
