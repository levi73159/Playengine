const std = @import("std");
const gl = @import("gl");
const glfw = @import("glfw");

const process = std.process;

const Window = @import("Window.zig");
const Shader = @import("Shader.zig");

const log = std.log.scoped(.core);

pub fn main() !u8 {
    const window = Window.init("Playengine", 800, 600, true) catch |err| {
        log.err("Failed to create window: {}", .{err});
        return 1;
    };
    defer window.deinit();

    const vertices: [2 * 3]f32 = .{
        -0.5, -0.5,
        0.5,  -0.5,
        0.5,  0.5,
    };

    var vao: u32 = undefined;
    gl.GenVertexArrays(1, @ptrCast(&vao));
    gl.BindVertexArray(vao);

    var buffer: u32 = undefined;
    gl.GenBuffers(1, @ptrCast(&buffer));
    gl.BindBuffer(gl.ARRAY_BUFFER, buffer);

    gl.BufferData(gl.ARRAY_BUFFER, vertices.len * @sizeOf(f32), &vertices, gl.STATIC_DRAW);

    gl.EnableVertexAttribArray(0);
    gl.VertexAttribPointer(0, 2, gl.FLOAT, gl.FALSE, 0, 0);

    const shader = Shader.init(@embedFile("shaders/vertex.glsl"), @embedFile("shaders/fragment.glsl")) catch |err| {
        log.err("Failed to create shader: {}", .{err});
        return 1;
    };
    defer shader.deinit();

    shader.use();

    while (!window.shouldClose()) {
        if (glfw.getKey(window.handle, glfw.KeyEscape) == glfw.Press) {
            window.setShouldClose(true);
        }

        gl.ClearColor(0.2, 0.3, 0.3, 1.0);
        gl.Clear(gl.COLOR_BUFFER_BIT);

        gl.DrawArrays(gl.TRIANGLES, 0, 3);

        window.swapBuffers();
        Window.pollEvents();
    }

    return 0;
}
