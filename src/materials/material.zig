const vector = @import("../vector.zig");
const Ray = @import("../Ray.zig");
const Random = @import("../Random.zig");

const Dielectric = @import("Dielectric.zig");
const Lambertian = @import("Lambertian.zig");
const Metal = @import("Metal.zig");

const Vec3f = vector.Vec3f;

const Self = @This();

pub const Material = union(enum) {
    Dielectric: Dielectric,
    Lambertian: Lambertian,
    Metal: Metal,

    pub fn scatter(
        material: *const Material,
        rand: *Random,
        ray: *const Ray,
        hit_record: *const Ray.HitRecord,
    ) !?Ray.ScatterRay {
        return switch (material.*) {
            inline else => |mat| try mat.scatter(rand, ray, hit_record),
        };
    }
};
