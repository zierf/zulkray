const std = @import("std");

const inf32 = std.math.inf(f32);

const Self = @This();

min: f32,
max: f32,

pub const IntervalError = error{
    MaxLessThanMin,
};

pub fn init(min: f32, max: f32) !Self {
    if (max < min) {
        return IntervalError.MaxLessThanMin;
    }

    return .{
        .min = min,
        .max = max,
    };
}

pub const empty: Self = .{
    .min = inf32,
    .max = -inf32,
};

pub const infinity: Self = .{
    .min = -inf32,
    .max = inf32,
};

pub fn size(self: *const Self) f32 {
    return self.max - self.min;
}

pub fn contains(self: *const Self, value: f32) bool {
    return value >= self.min and value <= self.max;
}

pub fn surrounds(self: *const Self, value: f32) bool {
    return value > self.min and value < self.max;
}

pub fn clamp(self: *const Self, value: f32) f32 {
    if (value < self.min) {
        return self.min;
    }
    if (value > self.max) {
        return self.max;
    }

    return value;
}
