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

const renderer = @import("renderer.zig");
const Color = @import("Color.zig");
const Object = @import("Object.zig");
const Texture = @import("Texture.zig");

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
    // square: xy, texture coords
    const vertices: [4 * 4]f32 = .{ 
        -0.5, -0.5, 0.0, 0.0,
        0.5, -0.5, 1.0, 0.0,
        0.5, 0.5, 1.0, 1.0,
        -0.5, 0.5, 0.0, 1.0
    };

    const indices: [6]u8 = .{
        0, 1, 2,
        2, 3, 0
    };
    // zig fmt: on

    var va = VertexArray.init(try Layout.initFromSlice(allocator, &.{
        .{ .ty = .float, .count = 2, .normalized = false },
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

    var shader = Shader.init(allocator, @embedFile("shaders/vertex.glsl"), @embedFile("shaders/fragment.glsl")) catch |err| {
        log.err("Failed to create shader: {}", .{err});
        return 1;
    };
    defer shader.deinit();

    shader.use();

    var texture = Texture.loadFromFile(allocator, "res/logo.png") catch |err| {
        log.err("Failed to load texture: {}", .{err});
        return 1;
    };
    defer texture.deinit();
    texture.bind(0);

    try shader.setTexture("u_Texture", texture);

    const obj = Object{
        .vertex_array = va,
        .vertex_buffer = buffer,
        .index_buffer = index_buffer,
    };

    while (!window.shouldClose()) {
        renderer.clear(Color.init(0.2, 0.3, 0.3, 1.0));

        try shader.setColor("u_Color", Color.white);
        renderer.render(obj, null); // no need to pass in shader because it's already bound

        window.swapBuffers();
        Window.pollEvents();
    }

    return 0;
}
