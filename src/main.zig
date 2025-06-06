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
const Camera = @import("Camera.zig");

const log = std.log.scoped(.core);

pub fn main() !u8 {
    var dbg = std.heap.DebugAllocator(.{}).init;
    defer _ = dbg.deinit();

    const allocator = dbg.allocator();

    const window = Window.init(allocator, .{ .title = "Playengine", .width = 800, .height = 600 }) catch |err| {
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
        .transform = .{ .pos = za.Vec2.zero(), .scale = za.Vec2.new(200, 200) },
    };

    var camera = Camera{};

    try shader.setTexture("u_Texture", texture);
    try shader.setColor("u_Color", Color.white);

    const input = window.input();
    while (!window.shouldClose()) {
        renderer.clear(Color.init(0.2, 0.3, 0.3, 1.0));

        if (input.getKeyPress(.escape)) {
            window.setShouldClose(true);
        }

        if (input.getKeyPress(.w)) {
            camera.pos.yMut().* += 1.0;
        }
        if (input.getKeyPress(.s)) {
            camera.pos.yMut().* -= 1.0;
        }
        if (input.getKeyPress(.a)) {
            camera.pos.xMut().* -= 1.0;
        }
        if (input.getKeyPress(.d)) {
            camera.pos.xMut().* += 1.0;
        }

        if (input.getKeyPress(.left)) {
            camera.rotation += 0.1;
        } else if (input.getKeyPress(.right)) {
            camera.rotation -= 0.1;
        }

        if (input.getKeyPress(.r)) {
            obj.transform.pos = za.Vec2.zero();
        }

        if (input.getKeyPress(.equal)) {
            camera.zoom += 0.1;
        } else if (input.getKeyPress(.minus)) {
            camera.zoom -= 0.1;
        }

        renderer.render(obj, camera, &shader); // no need to pass in shader because it's already bound

        window.swapBuffers();
        Window.pollEvents();
    }

    return 0;
}
