const std = @import("std");

pub const vector = @import("vector.zig");

const Vec3f = vector.Vec3f;
const Point3 = vector.Point3;
const ColorRgb = vector.ColorRgb;

const black = ColorRgb.init(.{ 0.0, 0.0, 0.0 });

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

    fn hitSphere(self: *const Self, center: *const Vec3f, radius: f32) ?f32 {
        const ray_to_sphere: Vec3f = center.subtractVec(self.origin);

        // simplified sphere intersection
        const a = self.direction.lengthSquared();
        const h = self.direction.dot(ray_to_sphere);
        const c = ray_to_sphere.lengthSquared() - (radius * radius);

        const discriminant: f32 = (h * h) - (a * c);

        // not hit (no sqaure root for negative values)
        if (discriminant < 0.0) {
            return null;
        }

        // solve simplified quadratic equation
        const x1 = (h - @sqrt(discriminant)) / a;

        if (x1 >= 0.0) {
            return x1;
        }

        const x2 = (h + @sqrt(discriminant)) / a;

        if (x2 >= 0.0) {
            return x2;
        }

        return null;
    }

    pub fn color(self: *const Self) ColorRgb {
        const sphere_center = Point3.init(.{ 0.0, 0.0, -1.0 });

        const sphere_hit_distance = self.hitSphere(&sphere_center, 0.5);

        if (sphere_hit_distance) |*hit_distance| {
            const sphere_center_to_hit = self.at(hit_distance.*).subtractVec(sphere_center);

            const normal_vector: Vec3f = sphere_center_to_hit.unit() catch {
                return black;
            };

            // each component of unit vector is between [−1,1], map to color from [0,1]
            const normal_color: ColorRgb = normal_vector.add(1.0).multiply(0.5);
            return normal_color;
        }

        // render background color, needs unit vector
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
