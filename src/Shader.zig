const std = @import("std");
const builtin = @import("builtin");

const gl = @import("gl");
const za = @import("zalgebra");

const Self = @This();

var id_bound: u32 = 0;
const not_found_warn: bool = true; // if false, warn when uniform is not found, if true, returns an error

id: u32,
cached_uniform_locations: std.StringHashMap(i32),

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

pub fn init(allocator: std.mem.Allocator, vertex_src: []const u8, fragment_src: []const u8) !Self {
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
        .cached_uniform_locations = std.StringHashMap(i32).init(allocator),
    };
}

// creates a new shader that is a basic textured shader with u_MVP and u_Texture and u_Color
pub fn getTexturedShader(allocator: std.mem.Allocator) !Self {
    const vertex_src = @embedFile("shaders/textured.vert");
    const fragment_src = @embedFile("shaders/textured.frag");
    return Self.init(allocator, vertex_src, fragment_src);
}

pub fn getColoredShader(allocator: std.mem.Allocator) !Self {
    const vertex_src = @embedFile("shaders/colored.vert");
    const fragment_src = @embedFile("shaders/colored.frag");
    return Self.init(allocator, vertex_src, fragment_src);
}

pub fn deinit(self: *Self) void {
    self.cached_uniform_locations.deinit();
    gl.DeleteProgram(self.id);
}

pub fn use(self: Self) void {
    if (self.id == id_bound) return;
    gl.UseProgram(self.id);
    id_bound = self.id;
}

const SetUniformError = error{UniformNotFound};

fn getUniformLocation(self: *Self, name: [:0]const u8) SetUniformError!i32 {
    if (self.cached_uniform_locations.get(name)) |location|
        return location;

    const location = gl.GetUniformLocation(self.id, name);
    if (location == -1) {
        if (!not_found_warn) return error.UniformNotFound;
        std.log.warn("Uniform not found: {s}", .{name});
    }

    self.cached_uniform_locations.put(name, location) catch unreachable;
    return location;
}

pub fn setColor(self: *Self, name: [:0]const u8, color: @import("Color.zig")) SetUniformError!void {
    self.use();

    const location = try self.getUniformLocation(name);
    gl.Uniform4f(location, color.r, color.g, color.b, color.a);
}

pub fn setFloat(self: *Self, name: [:0]const u8, value: f32) SetUniformError!void {
    self.use();

    const location = try self.getUniformLocation(name);
    gl.Uniform1f(location, value);
}

pub fn setInt(self: *Self, name: [:0]const u8, value: i32) SetUniformError!void {
    self.use();

    const location = try self.getUniformLocation(name);
    gl.Uniform1i(location, value);
}

/// Note: texture must be bound otherwise it will revert back to slot 0
pub fn setTexture(self: *Self, name: [:0]const u8, texture: @import("Texture.zig")) SetUniformError!void {
    self.use();

    const location = try self.getUniformLocation(name);
    if (texture.bound_slot == null) std.log.warn("Cannot get bound slot from texture: {s}", .{texture.path});
    gl.Uniform1i(location, @intCast(texture.bound_slot orelse 0));
}

pub fn setMat4(self: *Self, name: [:0]const u8, mat: za.Mat4) SetUniformError!void {
    self.use();

    const location = try self.getUniformLocation(name);
    gl.UniformMatrix4fv(location, 1, gl.TRUE, @ptrCast(&mat.data));
}
