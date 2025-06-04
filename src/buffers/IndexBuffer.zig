const std = @import("std");
const gl = @import("gl");

const Self = @This();

var id_bound: u32 = 0;

id: u32,
count: i32,
ty: u32,

pub fn init(comptime T: type, datav: []const T) Self {
    var id: u32 = undefined;
    gl.GenBuffers(1, @ptrCast(&id));
    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, id);

    gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, @intCast(datav.len * @sizeOf(T)), datav.ptr, gl.STATIC_DRAW);
    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, 0);

    return Self{
        .id = id,
        .count = @intCast(datav.len),

        .ty = switch (T) {
            u8 => gl.UNSIGNED_BYTE,
            u16 => gl.UNSIGNED_SHORT,
            u32 => gl.UNSIGNED_INT,
            else => @compileError("Unsupported index buffer type"),
        },
    };
}

pub fn deinit(self: Self) void {
    gl.DeleteBuffers(1, @ptrCast(@constCast(&self.id)));
}

pub fn bind(self: Self) void {
    if (id_bound == self.id) return;
    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, self.id);
    id_bound = self.id;
}

pub fn unbind() void {
    if (id_bound == 0) return;
    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, 0);
    id_bound = 0;
}
