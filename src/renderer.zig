const std = @import("std");

const buf = @import("buffer.zig");
const gl = @import("gl");
const za = @import("zalgebra");

const Color = @import("Color.zig");
const Object = @import("Object.zig");
const Shader = @import("Shader.zig");
const Window = @import("Window.zig");
const Camera = @import("Camera.zig");
const builtin = @import("builtin");

var procs: gl.ProcTable = undefined;
var renderer_window: *const Window = undefined;

var allocator: std.mem.Allocator = undefined;
var vertex_arrays: std.ArrayListUnmanaged(buf.VertexArray) = .{};

// difference between textured and colored is that in the vertex_buffers the textured square has texture coords
var textured_square_object: ?Object = null; // predefined only when createSquare is called
var colored_square_object: ?Object = null; // predefined only when createSquare is called

fn messageCallback(
    source: gl.@"enum",
    ty: gl.@"enum",
    id: gl.uint,
    severity: gl.@"enum",
    length: gl.sizei,
    message: [*:0]const gl.char,
    userParam: ?*const anyopaque,
) callconv(.c) void {
    _ = ty; // autofix
    _ = source; // autofix
    _ = id; // autofix
    _ = userParam; // autofix

    const message_str = message[0..@intCast(length)];

    const serverity_str = switch (severity) {
        gl.DEBUG_SEVERITY_HIGH => "fatal",
        gl.DEBUG_SEVERITY_MEDIUM => "err",
        gl.DEBUG_SEVERITY_LOW => "warn",
        gl.DEBUG_SEVERITY_NOTIFICATION => "debug",
        else => "unknown",
    };

    std.debug.print("{s}(gl): {s}\n", .{ serverity_str, message_str });

    if (severity == gl.DEBUG_SEVERITY_HIGH or severity == gl.DEBUG_SEVERITY_MEDIUM) {
        @breakpoint();
    }
}

pub fn init(window: *const Window) !void {
    const glfw = @import("glfw"); // import it here because we need the procsAddress here only

    if (!procs.init(glfw.getProcAddress)) return error.GLInitFailed;
    gl.makeProcTableCurrent(&procs);

    if (builtin.mode == .Debug) {
        gl.Enable(gl.DEBUG_OUTPUT);
        gl.DebugMessageCallback(messageCallback, null);
    }

    // enable blending
    gl.Enable(gl.BLEND);
    gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);

    gl.Viewport(0, 0, @intCast(window.info.width), @intCast(window.info.height));
    Window.registerFrameBufferSizeCallback(&framebufferSizeCallback);

    renderer_window = window;
    allocator = renderer_window.allocator;
}

pub fn deinit() void {
    for (vertex_arrays.items) |*va| {
        allocator.destroy(va.bound_buffer.?);
        va.deinit();
    }
    vertex_arrays.deinit(allocator);

    if (textured_square_object) |*o| o.deinit();
    if (colored_square_object) |*o| o.deinit();
}

pub fn createVertexArray(layout: buf.BufferLayout.Layout) !u32 {
    const id = vertex_arrays.items.len;
    const vertex_array = try vertex_arrays.addOne(allocator);
    vertex_array.* = buf.VertexArray.init(try buf.BufferLayout.init(layout));
    vertex_array.bound_buffer = try allocator.create(u32);
    vertex_array.bound_buffer.?.* = 0;
    vertex_array.bind();
    return @truncate(id);
}

pub fn bindVertexArray(id: u32) void {
    vertex_arrays.items[id].bind();
}

fn framebufferSizeCallback(width: u32, height: u32) void {
    gl.Viewport(0, 0, @intCast(width), @intCast(height));
}

pub fn clear(color: Color) void {
    gl.ClearColor(color.r, color.g, color.b, color.a);
    gl.Clear(gl.COLOR_BUFFER_BIT);
}

pub fn render(obj: Object, camera: Camera, shader: ?*Shader) void {
    const window_bounds = renderer_window.getBounds();
    if (!window_bounds.overlaps(obj.getBounds())) return;

    const va = vertex_arrays.items[obj.id];
    va.bindBuffer(obj.vertex_buffer);
    obj.index_buffer.bind();

    if (shader) |s| {
        s.use();
        s.setMat4("u_MVP", renderer_window.getProj()
            .mul(camera.getMat4())
            .mul(obj.transform.getMat4())) catch {};
    }

    gl.DrawElements(gl.TRIANGLES, obj.index_buffer.count, obj.index_buffer.ty, 0);
}

/// create a new textured square with the scale of 50x50
pub fn createSquare() !Object {
    if (textured_square_object) |o| return o;
    // zig fmt: off
    // square: xy, texture coords
    // square dimensions unscaled are -0.5 to 0.5 meaning a scale of 1 is 1x1 center based
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

    const vaid = try createVertexArray(buf.BufferLayout.texcords_layout);

    const vertex_buffer = buf.ArrayBuffer.initWithData(f32, &vertices, .static);
    const index_buffer = buf.IndexBuffer.init(u8, &indices);

    textured_square_object = Object{
        .id = vaid,
        .vertex_buffer = vertex_buffer,
        .index_buffer = index_buffer,
        .transform = .{ .pos = za.Vec2.zero(), .scale = za.Vec2.new(50, 50) },
    };
    return textured_square_object.?;
}

pub fn createBasicSquare() !Object {
    if (colored_square_object) |o| return o;
    // zig fmt: off
    // square: xy
    const vertices: [2 * 4]f32 = .{ 
        -0.5, -0.5, 
        0.5, -0.5,
        0.5, 0.5, 
        -0.5, 0.5, 
    };

    const indices: [6]u8 = .{
        0, 1, 2,
        2, 3, 0
    };
    // zig fmt: on

    const vaid = try createVertexArray(buf.BufferLayout.basic_layout);

    const vertex_buffer = buf.ArrayBuffer.initWithData(f32, &vertices, .static);
    const index_buffer = buf.IndexBuffer.init(u8, &indices);

    colored_square_object = Object{
        .id = vaid,
        .vertex_buffer = vertex_buffer,
        .index_buffer = index_buffer,
        .transform = .{ .pos = za.Vec2.zero(), .scale = za.Vec2.new(50, 50) },
    };
    return colored_square_object.?;
}
