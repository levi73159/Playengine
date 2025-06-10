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
const Text = @import("Text.zig");
const Bounds = @import("Bounds.zig");

const Font = @import("Font.zig");

const log = std.log.scoped(.core);

const c = @cImport({
    @cInclude("ft2build.h");
    @cInclude("freetype/freetype.h");
});

const Character = struct {
    texture_id: u32,
    size: za.Vec2_i32,
    bearing: za.Vec2_i32,
    advance: c_long,
};

const CharacterMap = std.AutoHashMap(u8, Character);

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

    renderer.deinitResources();

    var texture = Texture.loadFromFile(allocator, "res/sprites/image.png") catch |err| {
        log.err("Failed to load texture: {}", .{err});
        return 1;
    };
    defer texture.deinit();
    texture.bind(1);

    // ------------- SHADER INITIALIZATION -------------
    // initialize the two basic shaders (that we will always use)
    var shader = Shader.getTexturedShader(allocator) catch |err| {
        log.err("Failed to load textured shader: {}", .{err});
        return 1;
    };
    defer shader.deinit();

    var color_shader = Shader.getColoredShader(allocator) catch |err| {
        log.err("Failed to load colored shader: {}", .{err});
        return 1;
    };
    defer color_shader.deinit();

    var text_shader = Shader.init(allocator, @embedFile("shaders/text.vert"), @embedFile("shaders/text.frag")) catch |err| {
        log.err("Failed to load text shader: {}", .{err});
        return 1;
    };
    defer text_shader.deinit();

    // ---- Font Initialization ----
    var basic_font = Font.init(allocator, "res/fonts/Roboto.ttf", 48) catch |err| switch (err) {
        error.OutOfMemory => {
            std.log.err("Not enough memory to load font!!!!!!", .{});
            return 255; // fatal bad error is 255
        },
        error.FailedToLoadFont => {
            std.log.err("Failed to load font", .{});
            return 1;
        },
        error.FailedToInitFreeType => {
            std.log.err("Failed to init freetype", .{});
            return 1;
        },
    };
    defer basic_font.deinit();

    renderer.setFont(&basic_font);
    renderer.setFontColor(Color.white);

    var player = try Object.createSquare("player", &shader);
    player.transform.scale = za.Vec2.new(200, 200);
    player.texture = &texture;

    var obsticle = try Object.createBasicSquare("obsticle", &color_shader);
    obsticle.transform.scale = za.Vec2.new(200, 100);
    obsticle.transform.pos = za.Vec2.new(0, -200);
    obsticle.color = Color.red;

    var text = try Text.create("Text", "Game by levi", &text_shader, &basic_font);
    text.transform.pos = window.getBounds().topLeft().add(za.Vec2.new(0, -10));
    text.transform.scale = za.Vec2.new(100, 100);
    text.color = Color.white;
    text.scale = 1.0;

    const camera = Camera{};

    const input = window.input();
    const move_speed = 100.0;

    _ = input;
    _ = move_speed;

    while (!window.shouldClose()) {
        renderer.clear(Color.init(0.2, 0.3, 0.3, 1.0));

        renderer.renderAll(camera) catch |err| {
            log.err("Failed to render: {}", .{err});
            return 1;
        };

        window.swapBuffers();
        Window.pollEvents();
    }

    return 0;
}
