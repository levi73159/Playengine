const std = @import("std");

pub const TimeStamp = struct {
    delta: f32,
    time: f32,
};

var stamp: TimeStamp = .{ .delta = 0.0, .time = 0.0 };
var timer: ?std.time.Timer = null;

/// Initialize the timer and mark the start of frame tracking
pub fn startFrame() void {
    if (timer == null) {
        timer = std.time.Timer.start() catch |err| std.debug.panic("Failed to start timer: {s}", .{@errorName(err)});
        return;
    }

    const elapsed_ns = timer.?.lap(); // returns elapsed since last lap
    const elapsed_sec = @as(f32, @floatFromInt(elapsed_ns)) / @as(f32, std.time.ns_per_s);

    stamp.delta = elapsed_sec;
    stamp.time += elapsed_sec;
}

pub fn getStamp() TimeStamp {
    return stamp;
}

pub fn delta() f32 {
    return stamp.delta;
}

pub fn time() f32 {
    return stamp.time;
}
