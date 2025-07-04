const za = @import("zalgebra");
const Transform = @import("Transform.zig");

const Circle = @import("CircleBounds.zig");
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

pub fn fromTransform(transform: Transform) Self {
    return Self{
        .x = transform.pos.x(),
        .y = transform.pos.y(),
        .width = transform.scale.x(),
        .height = transform.scale.y(),
    };
}

pub fn zero() Self {
    return Self{
        .x = 0.0,
        .y = 0.0,
        .width = 0.0,
        .height = 0.0,
    };
}

pub fn left(self: Self) f32 {
    return (-self.width / 2.0) + self.x;
}

pub fn right(self: Self) f32 {
    return (self.width / 2.0) + self.x;
}

pub fn bottom(self: Self) f32 {
    return (-self.height / 2.0) + self.y;
}

pub fn top(self: Self) f32 {
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

pub inline fn center(self: Self) za.Vec2 {
    return za.Vec2.new(self.x, self.y);
}

pub inline fn size(self: Self) za.Vec2 {
    return za.Vec2.new(self.width, self.height);
}

pub inline fn halfSize(self: Self) za.Vec2 {
    return za.Vec2.new(self.width / 2.0, self.height / 2.0);
}

pub fn contains(self: Self, pos: za.Vec2) bool {
    return pos.x() >= self.left() and pos.x() <= self.right() and pos.y() >= self.bottom() and pos.y() <= self.top();
}

pub fn overlaps(self: Self, other: Self) bool {
    return self.left() < other.right() and self.right() > other.left() and self.bottom() < other.top() and self.top() > other.bottom();
}
