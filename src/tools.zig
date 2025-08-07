const std = @import("std");

const Random = @import("Random.zig");
const vector = @import("vector.zig");

const Vec3f = vector.Vec3f;
const ColorRgb = vector.ColorRgb;

pub fn lerpVector(percentage: f32, from: Vec3f, to: Vec3f) Vec3f {
    const inverted_percentage = 1.0 - percentage;

    const first = from.multiply(inverted_percentage);
    const second = to.multiply(percentage);

    return first.addVec(second);
}

pub fn reflectVector(vec: Vec3f, normal: Vec3f) Vec3f {
    return vec.subtractVec(
        normal.multiply(vec.dot(normal)).multiply(2.0),
    );
}

pub fn linearToGammaSpace(color: ColorRgb) !ColorRgb {
    var gamma_corrected = [1]f32{0} ** ColorRgb.dimension;

    for (&gamma_corrected, 0..) |*value, index| {
        if (color.vector[index] < 0.0) {
            return error.LinearToGammaConversion;
        }

        value.* = @sqrt(color.vector[index]);
    }

    return ColorRgb.init(gamma_corrected);
}

/// Get a vector to a random point in the [-0.5,-0.5]-[+0.5,+0.5] unit square.
pub fn pixelSampleSquare(rand: *Random) Vec3f {
    return Vec3f.init(.{
        rand.float() - 0.5,
        rand.float() - 0.5,
        0.0,
    });
}

pub fn randomVector(rand: *Random) Vec3f {
    return Vec3f.init(.{
        rand.float(),
        rand.float(),
        rand.float(),
    });
}

pub fn randomVectorBetween(rand: *Random, min: f32, max: f32) Vec3f {
    return Vec3f.init(.{
        rand.floatBetween(min, max),
        rand.floatBetween(min, max),
        rand.floatBetween(min, max),
    });
}

pub fn randomOnHemisphere(rand: *Random, normal: Vec3f) Vec3f {
    const on_unit_sphere: Vec3f = randomUnitVector(rand);

    if (on_unit_sphere.dot(normal) <= 0.0) {
        return on_unit_sphere.negate();
    }

    // in the same hemisphere as the normal
    return on_unit_sphere;
}

pub fn randomUnitVector(rand: *Random) Vec3f {
    while (true) {
        const random_vector = randomVectorBetween(rand, -1.0, 1.0);

        const length_squared = random_vector.lengthSquared();

        const isLengthNearZero = std.math.approxEqAbs(
            f32,
            0.0,
            length_squared,
            std.math.floatEps(f32),
        );

        if (!isLengthNearZero and length_squared <= 1.0) {
            // calculate unit vector, use already known squared length
            return random_vector.divide(@sqrt(length_squared)) catch unreachable;
        }
    }
}
