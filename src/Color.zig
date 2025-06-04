const Self = @This();

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
