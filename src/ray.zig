const std = @import("std");

pub const vector = @import("vector.zig");

const Vec3f = vector.Vec3f;
const Point3 = vector.Point3;
const ColorRgb = vector.ColorRgb;

pub const RayError = error{
    RayWithoutDirection,
};

pub const Ray = struct {
    const Self = @This();
    const ElementType = Vec3f.elementType();

    origin: Point3,
    direction: Vec3f,

    pub fn init(orig: Point3, dir: Vec3f) !Self {
        if (dir.isNearZero()) {
            return RayError.RayWithoutDirection;
        }

        return .{
            .origin = orig,
            // not normalized until needed
            .direction = dir,
        };
    }

    pub fn at(self: *const Self, distance: ElementType) Vec3f {
        return self.origin.addVec(
            self.direction.multiply(distance),
        );
    }

    pub fn color(self: *const Self) ColorRgb {
        const unit_direction: Vec3f = self.direction.unit() catch unreachable;

        // define color based on a bluish->white interpolated gradient from top to bottom
        const percentage = 0.5 * (unit_direction.y() + 1.0);

        return lerp(
            percentage,
            ColorRgb.init(.{ 1.0, 1.0, 1.0 }),
            ColorRgb.init(.{ 0.5, 0.7, 1.0 }),
        );
    }
};

fn lerp(percentage: f32, from: Vec3f, to: Vec3f) Vec3f {
    const inverted_percentage = 1.0 - percentage;

    const first = from.multiply(inverted_percentage);
    const second = to.multiply(percentage);

    return first.addVec(second);
}
