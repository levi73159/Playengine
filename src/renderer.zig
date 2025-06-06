const std = @import("std");

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
}

fn framebufferSizeCallback(width: u32, height: u32) void {
    gl.Viewport(0, 0, @intCast(width), @intCast(height));
}

pub fn clear(color: Color) void {
    gl.ClearColor(color.r, color.g, color.b, color.a);
    gl.Clear(gl.COLOR_BUFFER_BIT);
}

pub fn render(obj: Object, camera: Camera, shader: ?*Shader) void {
    obj.vertex_array.bind();
    obj.vertex_buffer.bind();
    obj.index_buffer.bind();

    if (shader) |s| {
        s.use();
        s.setMat4("u_MVP", renderer_window.getProj()
            .mul(camera.getMat4())
            .mul(obj.transform.getMat4())) catch {};
    }

    gl.DrawElements(gl.TRIANGLES, obj.index_buffer.count, obj.index_buffer.ty, 0);
}
