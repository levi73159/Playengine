const Self = @This();

pub const white = Self{ .r = 1.0, .g = 1.0, .b = 1.0, .a = 1.0 };
pub const black = Self{ .r = 0.0, .g = 0.0, .b = 0.0, .a = 1.0 };
pub const red = Self{ .r = 1.0, .g = 0.0, .b = 0.0, .a = 1.0 };
pub const green = Self{ .r = 0.0, .g = 1.0, .b = 0.0, .a = 1.0 };
pub const blue = Self{ .r = 0.0, .g = 0.0, .b = 1.0, .a = 1.0 };

r: f32,
g: f32,
b: f32,
a: f32,

pub fn init(r: f32, g: f32, b: f32, a: f32) Self {
    return Self{ .r = r, .g = g, .b = b, .a = a };
}

pub fn rgb(r: u8, g: u8, b: u8) Self {
    return rgba(r, g, b, 255);
}

pub fn rgba(r: u8, g: u8, b: u8, a: u8) Self {
    return Self{
        .r = @as(f32, @floatFromInt(r)) / 255.0,
        .g = @as(f32, @floatFromInt(g)) / 255.0,
        .b = @as(f32, @floatFromInt(b)) / 255.0,
        .a = @as(f32, @floatFromInt(a)) / 255.0,
    };
}
