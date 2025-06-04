const std = @import("std");
const gl = @import("gl");

const Self = @This();

const ElementType = enum(u32) {
    float = gl.FLOAT,
    double = gl.DOUBLE,
    short = gl.SHORT,
    byte = gl.BYTE,
    int = gl.INT,
    ubyte = gl.UNSIGNED_BYTE,
    ushort = gl.UNSIGNED_SHORT,
    uint = gl.UNSIGNED_INT,

    pub fn fromType(comptime T: type) ElementType {
        return switch (T) {
            f32 => .float,
            f64 => .double,
            i16 => .short,
            i8 => .byte,
            i32 => .int,
            u8 => .ubyte,
            u16 => .ushort,
            u32 => .uint,
            else => @compileError("Unsupported type: " ++ @typeName(T)),
        };
    }

    pub fn size(self: ElementType) u32 {
        return switch (self) {
            .float => @sizeOf(gl.float),
            .double => @sizeOf(gl.double),
            .short => @sizeOf(gl.short),
            .byte => @sizeOf(gl.byte),
            .int => @sizeOf(gl.int),
            .ubyte => @sizeOf(gl.ubyte),
            .ushort => @sizeOf(gl.ushort),
            .uint => @sizeOf(gl.uint),
        };
    }
};

pub const Element = struct {
    ty: ElementType,
    count: u32,
    normalized: bool,
};

elements: std.ArrayListUnmanaged(Element),
stride: u32 = 0,
allocator: std.mem.Allocator,

pub fn init(allocator: std.mem.Allocator) Self {
    return Self{
        .elements = .{},
        .allocator = allocator,
    };
}

pub fn initFromSlice(allocator: std.mem.Allocator, elements: []const Element) !Self {
    var self = init(allocator);
    try self.elements.appendSlice(self.allocator, elements);
    self.calculateStride();
    return self;
}

fn calculateStride(self: *Self) void {
    self.stride = 0;
    for (self.elements.items) |element| {
        self.stride += element.count * element.ty.size();
    }
}

pub fn deinit(self: *Self) void {
    self.elements.deinit(self.allocator);
}

pub fn add(self: *Self, comptime ty: type, count: u32, normalized: bool) !void {
    try self.elements.append(self.allocator, .{
        .count = count,
        .ty = ElementType.fromType(ty),
        .normalized = normalized,
    });

    self.stride += @sizeOf(ty) * count;
}
