const std = @import("std");
const gl = @import("gl");

const builtin = @import("builtin");

const Self = @This();

id: u32,

fn compile(src: []const u8, shader_type: gl.@"enum") !u32 {
    const id = gl.CreateShader(shader_type);
    gl.ShaderSource(id, 1, &.{src.ptr}, null);
    gl.CompileShader(id);

    var result: i32 = 0;
    gl.GetShaderiv(id, gl.COMPILE_STATUS, &result);

    if (result == 0) {
        var length: i32 = 0;
        gl.GetShaderiv(id, gl.INFO_LOG_LENGTH, &length);

        var log: [2048]u8 = undefined; // log size
        gl.GetShaderInfoLog(id, log.len, null, &log);
        std.log.err("Failed to compile shader", .{});
        switch (shader_type) {
            gl.VERTEX_SHADER => std.log.err("type: Vertex Shader", .{}),
            gl.FRAGMENT_SHADER => std.log.err("type: Fragment Shader", .{}),
            gl.COMPUTE_SHADER => std.log.err("type: Compute Shader", .{}),
            gl.GEOMETRY_SHADER => std.log.err("type: Geometry Shader", .{}),
            else => std.log.err("type: Unknown Shader", .{}),
        }
        std.debug.print("{s}", .{log});

        return error.CompilationFailed;
    }

    return id;
}

pub fn init(vertex_src: []const u8, fragment_src: []const u8) !Self {
    const vertex_id = try compile(vertex_src, gl.VERTEX_SHADER);
    defer gl.DeleteShader(vertex_id);

    const fragment_id = try compile(fragment_src, gl.FRAGMENT_SHADER);
    defer gl.DeleteShader(fragment_id);

    const program_id = gl.CreateProgram();

    gl.AttachShader(program_id, vertex_id);
    gl.AttachShader(program_id, fragment_id);
    gl.LinkProgram(program_id);
    gl.ValidateProgram(program_id);

    // remove shader src if not in debug (performance)
    if (builtin.mode != .Debug) {
        gl.DetachShader(program_id, vertex_id);
        gl.DetachShader(program_id, fragment_id);
    }

    return Self{
        .id = program_id,
    };
}

pub fn deinit(self: Self) void {
    gl.DeleteProgram(self.id);
}

pub fn use(self: Self) void {
    gl.UseProgram(self.id);
}
