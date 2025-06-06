const za = @import("zalgebra");

const Self = @This();

x: f32,
y: f32,
width: f32,
height: f32,

pub fn init(x: f32, y: f32, width: f32, height: f32) Self {
    return Self{
        .x = x,
        .y = y,
        .width = width,
        .height = height,
    };
}

pub fn left(self: Self) f32 {
    return (-self.width / 2.0) + self.x;
}

pub fn right(self: Self) f32 {
    return (self.width / 2.0) + self.x;
}

pub fn top(self: Self) f32 {
    return (-self.height / 2.0) + self.y;
}

pub fn bottom(self: Self) f32 {
    return (self.height / 2.0) + self.y;
}

pub inline fn bottomLeft(self: Self) za.Vec2 {
    return za.Vec2.new(self.left(), self.bottom());
}

pub inline fn bottomRight(self: Self) za.Vec2 {
    return za.Vec2.new(self.right(), self.bottom());
}

pub inline fn topRight(self: Self) za.Vec2 {
    return za.Vec2.new(self.right(), self.top());
}

pub inline fn topLeft(self: Self) za.Vec2 {
    return za.Vec2.new(self.left(), self.top());
}
