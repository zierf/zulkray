const std = @import("std");

const vector = @import("../vector.zig");
const Ray = @import("../Ray.zig");
const Random = @import("../Random.zig");
const tools = @import("../tools.zig");

const Vec3f = vector.Vec3f;
const ColorRgb = vector.ColorRgb;

const Self = @This();

// refractive index in vacuum or air, or the ratio
// of the material's refractive index over
// the refractive index of the enclosing media
refraction_index: f32,

pub fn init(refraction_index: f32) Self {
    return .{
        .refraction_index = refraction_index,
    };
}

pub fn scatter(
    self: *const Self,
    rand: *Random,
    ray: *const Ray,
    hit_record: *const Ray.HitRecord,
) !?Ray.ScatterRay {
    // also see Snell's Law
    const refraction_index = if (hit_record.*.is_front_face)
        (1.0 / self.refraction_index)
    else
        self.refraction_index;

    const unit_direction = try ray.direction.unit();

    const cos_theta: f32 = @min(
        unit_direction.negate().dot(hit_record.*.normal),
        1.0,
    );

    const sin_theta = @sqrt(1.0 - cos_theta * cos_theta);

    const can_refract: bool = (refraction_index * sin_theta) <= 1.0;
    const reflectance: bool = tools.reflectance(cos_theta, refraction_index) > rand.float();

    const ray_direction: Vec3f = if (can_refract and !reflectance)
        tools.refractVector(
            unit_direction,
            hit_record.*.normal,
            refraction_index,
        )
    else
        tools.reflectVector(
            unit_direction,
            hit_record.*.normal,
        );

    const scatter_ray = try Ray.init(hit_record.*.point, ray_direction);

    // doesn't absorb light
    const attenuation = ColorRgb.init(.{ 1.0, 1.0, 1.0 });

    return .{
        .ray = scatter_ray,
        .attenuation = attenuation,
    };
}
