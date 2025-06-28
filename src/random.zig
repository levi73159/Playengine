const std = @import("std");

const Random = std.Random;

pub const StaticState = struct {
    rand: Random,
    seed: u64,
    prng: Random.DefaultPrng,
};

var state: ?StaticState = null;

pub fn initSeed(seed: u64) void {
    var prng = Random.DefaultPrng.init(seed);
    state = StaticState{
        .rand = prng.random(),
        .seed = seed,
        .prng = prng,
    };
}

pub inline fn init() void {
    initSeed(std.crypto.random.int(u64));
}

pub inline fn random() Random {
    return state.?.rand;
}

pub inline fn getState() StaticState {
    return state.?;
}

/// Returns a random number between min and max
/// it is exclusion see `intInclusive` for inclusive
pub fn int(comptime T: type, min: T, max: T) T {
    return random().intRangeLessThan(T, min, max);
}

pub fn intInclusive(comptime T: type, min: T, max: T) T {
    return random().intRangeAtMost(T, min, max);
}

/// Returns a random number between min and max
/// it is exclusion see `intInclusive` for inclusive
pub fn float(comptime T: type, min: T, max: T) T {
    return random().float(T) * (max - min) + min;
}

pub fn floatInclusive(comptime T: type, min: T, max: T) T {
    return random().float(T) * (max - min + 1) + min;
}

pub fn floatMax(comptime T: type, max: T) T {
    return random().float(T) * max;
}

pub fn floatPercentage(comptime T: type) T {
    return random().float(T);
}
