const std = @import("std");
const builtin = @import("builtin");

const gl = @import("gl");
const glfw = @import("glfw");

var gl_initlized: bool = false;
var procs: gl.ProcTable = undefined;

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

pub fn initOpenGL() !void {
    if (gl_initlized) return;

    if (!procs.init(glfw.getProcAddress)) return error.GLInitFailed;
    gl.makeProcTableCurrent(&procs);
    gl_initlized = true;

    if (builtin.mode == .Debug) {
        gl.Enable(gl.DEBUG_OUTPUT);
        gl.DebugMessageCallback(messageCallback, null);
    }

    // enable blending
    gl.Enable(gl.BLEND);
    gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
}

const Version = struct { str: []const u8, major: i32, minor: i32, rev: i32 };

pub fn getVersions() struct { opengl: Version, glfw: Version } {
    var glfw_version: Version = undefined;
    glfw.getVersion(&glfw_version.major, &glfw_version.minor, &glfw_version.rev);
    glfw_version.str = glfw.getVersionString();

    var opengl_version: Version = undefined;
    opengl_version.str = gl.GetString(gl.VERSION);
    opengl_version.major = opengl_version.str[0] - '0';
    opengl_version.minor = opengl_version.str[2] - '0';
    opengl_version.rev = opengl_version.str[4] - '0';

    return .{
        .opengl = opengl_version,
        .glfw = glfw_version,
    };
}
