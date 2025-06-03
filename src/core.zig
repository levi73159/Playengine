const gl = @import("gl");
const glfw = @import("glfw");

var gl_initlized: bool = false;
var procs: gl.ProcTable = undefined;

pub fn initOpenGL() !void {
    if (gl_initlized) return;

    if (!procs.init(glfw.getProcAddress)) return error.GLInitFailed;
    gl.makeProcTableCurrent(&procs);
    gl_initlized = true;
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
