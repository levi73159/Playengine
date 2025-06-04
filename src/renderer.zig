const std = @import("std");
const gl = @import("gl");
const Object = @import("Object.zig");
const Shader = @import("Shader.zig");
const Color = @import("Color.zig");

pub fn clear(color: Color) void {
    gl.ClearColor(color.r, color.g, color.b, color.a);
    gl.Clear(gl.COLOR_BUFFER_BIT);
}

pub fn render(obj: Object, shader: ?Shader) void {
    obj.vertex_array.bind();
    obj.vertex_buffer.bind();
    obj.index_buffer.bind();

    if (shader) |s| s.use();

    gl.DrawElements(gl.TRIANGLES, obj.index_buffer.count, obj.index_buffer.ty, 0);
}
