const std = @import("std");
const gl = @import("gl");

const Self = @This();

var id_bound: u32 = 0;

id: u32,

const BufferUsage = enum(u32) {
    static = gl.STATIC_DRAW,
    dynamic = gl.DYNAMIC_DRAW,
    stream = gl.STREAM_DRAW,
};

// initlize an empty buffer
pub fn init() Self {
    var id: u32 = undefined;
    gl.GenBuffers(1, @ptrCast(&id));

    return Self{
        .id = id,
    };
}

pub fn initWithData(comptime T: type, datav: []const T, usage: BufferUsage) Self {
    const self = init();

    self.data(T, datav, usage);
    return self;
}

pub fn deinit(self: Self) void {
    gl.DeleteBuffers(1, @ptrCast(@constCast(&self.id)));
}

pub fn bind(self: Self) void {
    if (id_bound == self.id) return;
    id_bound = self.id;
    gl.BindBuffer(gl.ARRAY_BUFFER, self.id);
}

pub fn unbind() void {
    if (id_bound == 0) return;
    id_bound = 0;
    gl.BindBuffer(gl.ARRAY_BUFFER, 0);
}

/// NOTE: binds the buffer
pub fn data(self: Self, comptime T: type, datav: []const T, usage: BufferUsage) void {
    self.bind();
    gl.BufferData(gl.ARRAY_BUFFER, @intCast(datav.len * @sizeOf(T)), datav.ptr, @intFromEnum(usage));
}
