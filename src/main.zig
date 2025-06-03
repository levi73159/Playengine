const std = @import("std");
const gl = @import("gl");
const glfw = @import("glfw");

const process = std.process;

const Window = @import("Window.zig");

const log = std.log.scoped(.core);

var glProc: gl.ProcTable = undefined;

pub fn main() !void {
    const window = Window.init("Playengine", 800, 600, true) catch |err| {
        log.err("Failed to create window: {}", .{err});
        process.exit(1);
    };
    defer window.deinit();

    while (!window.shouldClose()) {
        if (glfw.getKey(window, glfw.KeyEscape) == glfw.Press) {
            window.setShouldClose(true);
        }

        gl.ClearColor(0.2, 0.3, 0.3, 1.0);
        gl.Clear(gl.COLOR_BUFFER_BIT);

        glfw.swapBuffers(window);
        glfw.pollEvents();
    }
}
