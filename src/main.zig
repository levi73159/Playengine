const std = @import("std");
const gl = @import("gl");
const glfw = @import("glfw");
const za = @import("zalgebra");
const buf = @import("buffer.zig");

const process = std.process;

const ArrayBuffer = buf.ArrayBuffer;
const VertexArray = buf.VertexArray;
const IndexBuffer = buf.IndexBuffer;
const Layout = buf.BufferLayout;

const renderer = @import("renderer.zig");
const Window = @import("Window.zig");
const Shader = @import("Shader.zig");
const Color = @import("Color.zig");
const Object = @import("Object.zig");
const Texture = @import("Texture.zig");

const log = std.log.scoped(.core);

pub fn main() !u8 {
    var dbg = std.heap.DebugAllocator(.{}).init;
    defer _ = dbg.deinit();

    const allocator = dbg.allocator();

    const window = Window.init(allocator, "Playengine", 800, 600, true) catch |err| {
        log.err("Failed to create window: {}", .{err});
        return 1;
    };
    defer window.deinit();

    renderer.init(&window) catch {
        log.err("Failed to initialize renderer", .{});
        return 1;
    };

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

    var texture = Texture.loadFromFile(allocator, "res/image.png") catch |err| {
        log.err("Failed to load texture: {}", .{err});
        return 1;
    };
    defer texture.deinit();
    texture.bind(0);

    var obj = Object{
        .vertex_array = va,
        .vertex_buffer = buffer,
        .index_buffer = index_buffer,
        .transform = .{ .pos = window.getCenter(), .scale = za.Vec2.new(200, 200) },
    };

    try shader.setTexture("u_Texture", texture);
    try shader.setColor("u_Color", Color.white);

    while (!window.shouldClose()) {
        renderer.clear(Color.init(0.2, 0.3, 0.3, 1.0));

        if (glfw.getKey(window.handle, glfw.KeyEscape) == glfw.Press) {
            window.setShouldClose(true);
        }

        if (glfw.getKey(window.handle, glfw.KeyW) == glfw.Press) {
            obj.transform.pos.yMut().* += 1.0;
        }
        if (glfw.getKey(window.handle, glfw.KeyS) == glfw.Press) {
            obj.transform.pos.yMut().* -= 1.0;
        }
        if (glfw.getKey(window.handle, glfw.KeyA) == glfw.Press) {
            obj.transform.pos.xMut().* -= 1.0;
        }
        if (glfw.getKey(window.handle, glfw.KeyD) == glfw.Press) {
            obj.transform.pos.xMut().* += 1.0;
        }

        if (glfw.getKey(window.handle, glfw.KeyC) == glfw.Press) {
            obj.transform.pos = window.getCenter();
        }

        try shader.setMat4("u_MVP", window.info.proj.mul(obj.transform.getMat4()));
        renderer.render(obj, null); // no need to pass in shader because it's already bound

        window.swapBuffers();
        Window.pollEvents();
    }

    return 0;
}
