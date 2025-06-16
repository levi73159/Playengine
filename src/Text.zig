const std = @import("std");
const gl = @import("gl");
const za = @import("zalgebra");

const Font = @import("Font.zig");
const Transform = @import("Transform.zig");
const Color = @import("Color.zig");
const Shader = @import("Shader.zig");
const buf = @import("buffer.zig");
const Camera = @import("Camera.zig");
const Rect = @import("RectBounds.zig");

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
zindex: i32 = 0, // only used if world_space is true
visible: bool = true,
do_not_destroy: bool = false,

pub fn deinitResources() void {
    if (shared_vao) |*vao| vao.deinit();
    if (shared_buffer) |*buffer| buffer.deinit();
}

pub fn destroy(self: *Self, allocator: std.mem.Allocator) void {
    allocator.destroy(self);
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
    return @import("renderer.zig").createText(name, text, shader, font, true);
}

pub inline fn createNoAdd(name: []const u8, text: []const u8, shader: *Shader, font: *const Font) !*Self {
    return @import("renderer.zig").createText(name, text, shader, font, false);
}

// getting text bounds not centered around transform
pub fn getBounds(self: *const Self) Rect {
    return getBoundsFromText(self.text, self.scale, self.font);
}

// get bounds for text with bounds.x,y being the position at the text if it were to be at 0,0 (centered)
pub fn getBoundsFromText(text: []const u8, scale: f32, font: *const Font) Rect {
    var max_width: f32 = 0;
    var total_height: f32 = 0;
    var line_width: f32 = 0;
    var line_height: f32 = 0;

    for (text) |c| {
        const char = font.getCharacter(c) orelse continue;

        if (c == '\n') {
            total_height += line_height + 10; // 10 px line spacing
            if (line_width > max_width) max_width = line_width;
            line_width = 0;
            line_height = 0;
            continue;
        }

        const advance: f32 = @as(f32, @floatFromInt(char.advance >> 6)) * scale;
        const height: f32 = @as(f32, @floatFromInt(char.size[1])) * scale;

        line_width += advance;
        if (height > line_height) line_height = height;
    }

    // Final line
    total_height += line_height + 10; // 10 px line spacing
    if (line_width > max_width) max_width = line_width;

    // Center-based rect (0,0 is center)
    const base = Rect{
        .x = -max_width / 2.0,
        .y = -total_height / 2.0,
        .width = max_width,
        .height = total_height,
    };
    return base;
}
