const std = @import("std");
const za = @import("zalgebra");

const Self = @This();

pos: za.Vec2 = za.Vec2.zero(),
rotation: f32 = 0.0,
zoom: f32 = 1.0,

pub fn init(pos: za.Vec2, rotation: f32, zoom: f32) Self {
    return Self{
        .pos = pos,
        .rotation = rotation,
        .zoom = zoom,
    };
}

pub fn getMat4(self: Self) za.Mat4 {
    return za.Mat4.fromRotation(self.rotation, za.Vec3.new(0, 0, 1)).translate(self.pos.toVec3(0)).scale(za.Vec3.new(self.zoom, self.zoom, 1));
}
