const std = @import("std");

const Self = @This();

threadlocal var rand_state: ?std.Random.Xoshiro256 = undefined;

/// Create a random generator.
///
/// Ensures that the random state will be initialized before use.
pub fn init(seed: ?u64) Self {
    if (rand_state != null) {
        return .{};
    }

    const prng = if (seed) |s| std.Random.DefaultPrng.init(s) else blk: {
        var init_seed: u64 = seed orelse @as(u64, @bitCast(std.time.milliTimestamp()));

        std.posix.getrandom(std.mem.asBytes(&init_seed)) catch |err| {
            std.debug.panic("Failed to create random seed: {}\n", .{err});
        };

        break :blk std.Random.DefaultPrng.init(init_seed);
    };

    rand_state = prng;

    return .{};
}

pub fn float(self: *Self) f32 {
    _ = self;
    const rand = rand_state.?.random();

    return rand.float(f32);
}

pub fn floatBetween(self: *Self, min: f32, max: f32) f32 {
    _ = self;
    const rand = rand_state.?.random();

    // random real in [min,max).
    return rand.float(f32) * (max - min) + min;
}
