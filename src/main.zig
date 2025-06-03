const std = @import("std");
const gl = @import("gl");
const glfw = @import("glfw");

var glProc: gl.ProcTable = undefined;

pub fn main() !void {
    var major: i32 = 0;
    var minor: i32 = 0;
    var rev: i32 = 0;

    glfw.getVersion(&major, &minor, &rev);
    std.debug.print("GLFW version {d}.{d}.{d}\n", .{ major, minor, rev });

    try glfw.init();
    defer glfw.terminate();
    std.debug.print("GLFW initialized\n", .{});

    const window = try glfw.createWindow(800, 640, "Playengine", null, null);
    defer glfw.destroyWindow(window);

    std.debug.print("GLFW window created\n", .{});

    glfw.makeContextCurrent(window);
    defer glfw.makeContextCurrent(null);

    if (!glProc.init(glfw.getProcAddress)) return error.GLInitFailed;

    gl.makeProcTableCurrent(&glProc);
    defer gl.makeProcTableCurrent(null);

    while (!glfw.windowShouldClose(window)) {
        if (glfw.getKey(window, glfw.KeyEscape) == glfw.Press) {
            glfw.setWindowShouldClose(window, true);
        }

        gl.ClearColor(0.2, 0.3, 0.3, 1.0);
        gl.Clear(gl.COLOR_BUFFER_BIT);

        glfw.swapBuffers(window);
        glfw.pollEvents();
    }
}
