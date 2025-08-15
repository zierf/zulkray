const vector = @import("../vector.zig");
const Ray = @import("../Ray.zig");
const Random = @import("../Random.zig");
const tools = @import("../tools.zig");

const ColorRgb = vector.ColorRgb;

const Self = @This();

albedo: ColorRgb,

pub fn init(albedo: ColorRgb) Self {
    return .{
        .albedo = albedo,
    };
}

pub fn scatter(
    self: *const Self,
    rand: *Random,
    ray: *const Ray,
    hit_record: *const Ray.HitRecord,
) !?Ray.ScatterRay {
    _ = ray;

    // lambertian reflection
    var scatter_direction = hit_record.*.normal.addVec(
        &tools.randomUnitVector(rand),
    );

    // catch degenerate scatter direction
    // (random unit vector could be the opposite of the normal)
    if (scatter_direction.isNearZero()) {
        scatter_direction = hit_record.*.normal;
    }

    const scatter_ray = try Ray.init(hit_record.*.point, scatter_direction);

    return .{
        .ray = scatter_ray,
        .attenuation = self.albedo,
    };
}
