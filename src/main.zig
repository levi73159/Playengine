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

const time = @import("time.zig");
const renderer = @import("renderer.zig");
const Window = @import("Window.zig");
const Shader = @import("Shader.zig");
const Color = @import("Color.zig");
const Object = @import("Object.zig");
const Texture = @import("Texture.zig");
const Camera = @import("Camera.zig");
const Bounds = @import("Bounds.zig");

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
    defer renderer.deinit();

    var player = try Object.createSquare();
    player.transform.scale = za.Vec2.new(200, 200);

    var obsticle = try Object.createBasicSquare();
    obsticle.transform.scale = za.Vec2.new(200, 100);
    obsticle.transform.pos = za.Vec2.new(0, -200);

    var shader = try Shader.getTexturedShader(allocator);
    defer shader.deinit();

    var color_shader = try Shader.getColoredShader(allocator);
    defer color_shader.deinit();

    var texture = Texture.loadFromFile(allocator, "res/image.png") catch |err| {
        log.err("Failed to load texture: {}", .{err});
        return 1;
    };
    defer texture.deinit();
    texture.bind(0);

    const camera = Camera{};

    try shader.setTexture("u_Texture", texture);
    try shader.setColor("u_Color", Color.white);

    try color_shader.setColor("u_Color", Color.red);

    const input = window.input();
    const move_speed = 100.0;
    while (!window.shouldClose()) {
        time.startFrame();
        const dt = time.delta();
        renderer.clear(Color.init(0.2, 0.3, 0.3, 1.0));

        var new_transform = player.transform;
        if (input.getKeyPress(.w)) {
            new_transform.pos.yMut().* += move_speed * dt;
        }
        if (input.getKeyPress(.s)) {
            new_transform.pos.yMut().* -= move_speed * dt;
        }
        if (input.getKeyPress(.a)) {
            new_transform.pos.xMut().* -= move_speed * dt;
        }
        if (input.getKeyPress(.d)) {
            new_transform.pos.xMut().* += move_speed * dt;
        }

        const bounds = Bounds.fromTransform(new_transform);
        if (!bounds.overlaps(obsticle.getBounds())) {
            player.transform = new_transform;
        }

        renderer.render(player, camera, &shader); // no need to pass in shader because it's already bound
        renderer.render(obsticle, camera, &color_shader);

        window.swapBuffers();
        Window.pollEvents();
    }

    return 0;
}
