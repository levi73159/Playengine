const za = @import("zalgebra");
const Transform = @import("Transform.zig");

const Self = @This();

x: f32,
y: f32,
radius: f32,

pub fn init(x: f32, y: f32, radius: f32) Self {
    return Self{
        .x = x,
        .y = y,
        .radius = radius,
    };
}

/// this is a perfect circle not an ellipse, so the width and height should be the same (uses the width for the radius)
pub fn fromTransform(transform: Transform) Self {
    return Self{
        .x = transform.pos.x(),
        .y = transform.pos.y(),
        .radius = transform.scale.x() / 2.0,
    };
}

pub fn fromPoint(point: za.Vec2, radius: f32) Self {
    return Self{
        .x = point.x(),
        .y = point.y(),
        .radius = radius,
    };
}

pub fn contains(self: Self, pos: za.Vec2) bool {
    const distance = pos.sub(za.Vec2.new(self.x, self.y)).length();
    return distance <= self.radius;
}

// check if two circles overlap
pub fn overlaps(self: Self, other: Self) bool {
    const distance = za.Vec2.new(self.x, self.y).sub(za.Vec2.new(other.x, other.y)).length();
    return distance <= self.radius + other.radius;
}

pub fn halfSize(self: Self) za.Vec2 {
    return za.Vec2.new(self.radius, self.radius);
}

pub fn left(self: Self) f32 {
    return self.x - self.radius;
}

pub fn right(self: Self) f32 {
    return self.x + self.radius;
}

pub fn bottom(self: Self) f32 {
    return self.y - self.radius;
}

pub fn top(self: Self) f32 {
    return self.y + self.radius;
}
