const std = @import("std");
const Self = @This();

const gl = @import("gl");
const zigimg = @import("zigimg");

id: u32,
path: []const u8, // more for debugging

width: u32,
height: u32,
bpp: u32,
allocator: std.mem.Allocator,

bound_slot: ?u32 = null,

pub fn loadFromFile(allocator: std.mem.Allocator, path: []const u8) !Self {
    var id: u32 = undefined;
    gl.GenTextures(1, @ptrCast(&id));
    errdefer gl.DeleteTextures(1, @ptrCast(&id));

    var image = try zigimg.Image.fromFilePath(allocator, path);
    defer image.deinit();

    try image.flipVertically();

    const image_format: struct { internal: gl.int, format: gl.@"enum" } = blk: {
        if (image.pixelFormat().isRgba()) {
            break :blk .{ .internal = gl.RGBA8, .format = gl.RGBA };
        }
        if (image.pixelFormat().isStandardRgb()) {
            break :blk .{ .internal = gl.RGB8, .format = gl.RGB };
        }

        return error.UnsupportedImageFormat;
    };

    gl.BindTexture(gl.TEXTURE_2D, id);

    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);

    const image_data = image.pixels.asConstBytes();
    gl.TexImage2D(gl.TEXTURE_2D, 0, image_format.internal, @intCast(image.width), @intCast(image.height), 0, image_format.format, gl.UNSIGNED_BYTE, image_data.ptr);

    return Self{
        .id = id,
        .path = path,
        .width = @intCast(image.width),
        .height = @intCast(image.height),
        .bpp = 4,
        .allocator = allocator,
    };
}

pub fn deinit(self: *Self) void {
    gl.DeleteTextures(1, @ptrCast(&self.id));
}

pub fn bind(self: *Self, slot: u32) void {
    self.bound_slot = slot;
    gl.ActiveTexture(gl.TEXTURE0 + slot);
    gl.BindTexture(gl.TEXTURE_2D, self.id);
}

pub fn unbind() void {
    gl.BindTexture(gl.TEXTURE_2D, 0);
}
