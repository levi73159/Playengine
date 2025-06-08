const std = @import("std");

const buffer = @import("buffer.zig");
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
var vertex_arrays: std.ArrayListUnmanaged(buffer.VertexArray) = .{};

// difference between textured and colored is that in the vertex_buffers the textured square has texture coords
var textured_square_object: ?Object = null; // predefined only when createSquare is called
var colored_square_object: ?Object = null; // predefined only when createSquare is called

var active_objects: std.ArrayListUnmanaged(*Object) = .{};
var sorted: bool = false;

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

    for (active_objects.items) |o| {
        o.deinit();
        allocator.destroy(o);
    }
    active_objects.deinit(allocator);

    if (textured_square_object) |*o| o.deinit();
    if (colored_square_object) |*o| o.deinit();
}

pub fn createVertexArray(layout: buffer.BufferLayout.Layout) !u32 {
    const id = vertex_arrays.items.len;
    const vertex_array = try vertex_arrays.addOne(allocator);
    vertex_array.* = buffer.VertexArray.init(try buffer.BufferLayout.init(layout));
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

fn lessThen(_: void, a: *Object, b: *Object) bool {
    return a.zindex < b.zindex;
}

fn sortObjects() void {
    if (sorted) return; // already sorted
    std.mem.sort(*Object, active_objects.items, {}, lessThen);
    sorted = true;
}

// once added the object is owned by the renderer and deinit will be called when needed
pub fn addObject(o: Object) !void {
    const ptr = try allocator.create(Object);
    ptr.* = o;
    try active_objects.append(allocator, ptr);
    sorted = false;
}

pub fn getObject(index: usize) *Object {
    return &active_objects.items[index];
}

pub fn findObject(name: []const u8) ?*Object {
    for (active_objects.items) |*o| {
        if (std.mem.eql(u8, o.name, name)) return o;
    }
    return null;
}

// if you want to find all objects with a certain name
// does not return pointers, if you want to have them return pointers use findObjectsMut
pub fn findObjects(objbuf: []Object, name: []const u8) []Object {
    var i: u32 = 0;
    for (active_objects.items) |o| {
        if (std.mem.eql(u8, o.name, name)) {
            objbuf[i] = o;
            i += 1;
        }
    }
    return objbuf[0..i];
}

pub fn findObjectsMut(objbuf: []*Object, name: []const u8) []*Object {
    var i: u32 = 0;
    for (active_objects.items) |*o| {
        if (std.mem.eql(u8, o.name, name)) {
            objbuf[i] = o;
            i += 1;
        }
    }
    return objbuf[0..i];
}

// if we only want to find a limited number of objects (good for performance so we don't search the whole array)
pub fn findObjectsLimited(objbuf: []Object, name: []const u8, limit: u32) u32 {
    var i: u32 = 0;
    for (active_objects.items) |o| {
        if (std.mem.eql(u8, o.name, name)) {
            objbuf[i] = o;
            i += 1;
            if (i == limit) return i;
        }
    }
    return i;
}

pub fn findObjectsLimitedMut(objbuf: []*Object, name: []const u8, limit: u32) u32 {
    var i: u32 = 0;
    for (active_objects.items) |*o| {
        if (std.mem.eql(u8, o.name, name)) {
            objbuf[i] = o;
            i += 1;
            if (i == limit) return i;
        }
    }
    return i;
}

pub fn renderAll(camera: Camera) !void {
    if (active_objects.items.len == 0) return;
    sortObjects(); // based on zindex

    for (active_objects.items) |o| {
        try renderObject(o, camera);
    }
}

pub fn renderObject(obj: *const Object, camera: Camera) !void {
    if (!obj.visible) return;

    const window_bounds = renderer_window.getBounds();
    if (!window_bounds.overlaps(obj.getBounds())) return;

    const va = vertex_arrays.items[obj.id];
    va.bindBuffer(obj.vertex_buffer);
    obj.index_buffer.bind();

    obj.shader.use();
    obj.shader.setMat4("u_MVP", renderer_window.getProj()
        .mul(camera.getMat4())
        .mul(obj.transform.getMat4())) catch {};

    obj.shader.setColor("u_Color", obj.color) catch {};

    if (obj.texture) |texture| {
        const slot = obj.texture_slot orelse texture.bound_slot orelse 0; // 0 is default texture slot
        texture.bind(slot);
        // instead of using catch {} on the error, if texture is not null, we gurantee that u_Texture is a valid uniform
        try obj.shader.setTexture("u_Texture", texture);
    }

    var buf: [100]u8 = undefined;
    for (obj.uniforms.keys(), obj.uniforms.values()) |name, value| {
        // convert name ([]const u8) to ([:0]const u8)
        if (name.len + 1 > buf.len) return error.BufferTooSmall;
        @memcpy(buf[0..name.len], name);
        buf[name.len] = 0;
        try obj.shader.setUniform(buf[0 .. name.len + 1 :0], value);
    }

    gl.DrawElements(gl.TRIANGLES, obj.index_buffer.count, obj.index_buffer.ty, 0);
}

/// creates a basic square and add it to the active objects
pub fn createSquare(name: []const u8, shader: *Shader) !*Object {
    if (textured_square_object) |o| {
        var cloned = try o.clone();
        cloned.name = name;
        const index = active_objects.items.len;
        try addObject(cloned);
        return active_objects.items[index];
    }
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

    const vaid = try createVertexArray(buffer.BufferLayout.texcords_layout);

    const vertex_buffer = buffer.ArrayBuffer.initWithData(f32, &vertices, .static);
    const index_buffer = buffer.IndexBuffer.init(u8, &indices);

    textured_square_object = Object{
        .id = vaid,
        .name = name,
        .vertex_buffer = vertex_buffer,
        .index_buffer = index_buffer,
        .transform = .{ .pos = za.Vec2.zero(), .scale = za.Vec2.new(50, 50) },
        .color = Color.white,
        .shader = shader,
        .static = true,
        .allocator = allocator,
    };
    const index = active_objects.items.len;
    try addObject(textured_square_object.?);
    return active_objects.items[index];
}

// creates basic square and adds it to the active objects
pub fn createBasicSquare(name: []const u8, shader: *Shader) !*Object {
    if (colored_square_object) |o| {
        var cloned = try o.clone();
        cloned.name = name;
        const index = active_objects.items.len;
        try addObject(cloned);
        return active_objects.items[index];
    }
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

    const vaid = try createVertexArray(buffer.BufferLayout.basic_layout);

    const vertex_buffer = buffer.ArrayBuffer.initWithData(f32, &vertices, .static);
    const index_buffer = buffer.IndexBuffer.init(u8, &indices);

    colored_square_object = Object{
        .name = name,
        .id = vaid,
        .vertex_buffer = vertex_buffer,
        .index_buffer = index_buffer,
        .transform = .{ .pos = za.Vec2.zero(), .scale = za.Vec2.new(50, 50) },
        .color = Color.white,
        .shader = shader,
        .static = true,
        .allocator = allocator,
    };
    const index = active_objects.items.len;
    try addObject(colored_square_object.?);
    return active_objects.items[index];
}
