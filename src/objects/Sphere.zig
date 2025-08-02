const vector = @import("../vector.zig");
const Interval = @import("../Interval.zig");
const Ray = @import("../Ray.zig");

const Vec3f = vector.Vec3f;
const Point3 = vector.Point3;

const Self = @This();

center: Point3,
radius: f32,

pub const SphereError = error{
    SphereWithNegativeRadius,
};

pub fn init(center: Point3, radius: f32) !Self {
    if (radius < 0) {
        return SphereError.SphereWithNegativeRadius;
    }

    return .{
        .center = center,
        .radius = radius,
    };
}

pub fn hit(self: *const Self, ray: *const Ray, ray_limits: *const Interval) ?Ray.HitRecord {
    const ray_to_sphere: Vec3f = self.center.subtractVec(ray.origin);

    // simplified sphere intersection (quadratic equation)
    const a = ray.direction.lengthSquared();
    const h = ray.direction.dot(ray_to_sphere);
    const c = ray_to_sphere.lengthSquared() - (self.radius * self.radius);

    const discriminant: f32 = (h * h) - (a * c);

    // not hit (no sqaure root for negative values)
    if (discriminant < 0.0) {
        return null;
    }

    const sqrt_discriminant = @sqrt(discriminant);

    // find the nearest intersection
    var root = (h - sqrt_discriminant) / a;

    // check acceptable range
    if (!ray_limits.surrounds(root)) {
        root = (h + sqrt_discriminant) / a;

        // check second intersection
        if (!ray_limits.surrounds(root)) {
            return null;
        }
    }

    // found a valid hit
    const hit_point = ray.at(root);

    // division by radius prevents calculating the vector length
    const sphere_normal = hit_point.subtractVec(self.center).divide(self.radius) catch {
        return null;
    };

    return Ray.HitRecord{
        .distance = root,
        .point = hit_point,
        .normal = sphere_normal,
    };
}
