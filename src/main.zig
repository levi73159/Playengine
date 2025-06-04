const std = @import("std");
const gl = @import("gl");
const glfw = @import("glfw");

const process = std.process;

const Window = @import("Window.zig");
const Shader = @import("Shader.zig");

const log = std.log.scoped(.core);
const buf = @import("buffer.zig");

const ArrayBuffer = buf.ArrayBuffer;
const VertexArray = buf.VertexArray;
const IndexBuffer = buf.IndexBuffer;
const Layout = buf.BufferLayout;

pub fn main() !u8 {
    var dbg = std.heap.DebugAllocator(.{}).init;
    defer _ = dbg.deinit();

    const allocator = dbg.allocator();

    const window = Window.init("Playengine", 800, 600, true) catch |err| {
        log.err("Failed to create window: {}", .{err});
        return 1;
    };
    defer window.deinit();

    // zig fmt: off
    const vertices: [2 * 4]f32 = .{ 
        -0.5, -0.5,
        0.5, -0.5,
        0.5, 0.5,
        -0.5, 0.5
    };

    const indices: [6]u8 = .{
        0, 1, 2,
        2, 3, 0
    };
    // zig fmt: on

    var va = VertexArray.init(try Layout.initFromSlice(allocator, &.{
        .{ .ty = .float, .count = 2, .normalized = false },
    }));
    defer va.deinit();
    va.bind();

    const buffer = ArrayBuffer.initWithData(f32, &vertices, .static);
    defer buffer.deinit();

    va.addBuffer(buffer);

    const index_buffer = IndexBuffer.init(u8, &indices);
    defer index_buffer.deinit();

    index_buffer.bind();

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

        gl.DrawElements(gl.TRIANGLES, index_buffer.count, gl.UNSIGNED_BYTE, 0);

        window.swapBuffers();
        Window.pollEvents();
    }

    return 0;
}
