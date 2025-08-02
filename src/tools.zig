const vector = @import("vector.zig");
const Vec3f = vector.Vec3f;

pub fn lerpVector(percentage: f32, from: Vec3f, to: Vec3f) Vec3f {
    const inverted_percentage = 1.0 - percentage;

    const first = from.multiply(inverted_percentage);
    const second = to.multiply(percentage);

    return first.addVec(second);
}
