const vector = @import("../vector.zig");
const Ray = @import("../Ray.zig");
const Random = @import("../Random.zig");
const tools = @import("../tools.zig");

const Vec3f = vector.Vec3f;
const ColorRgb = vector.ColorRgb;

const Self = @This();

albedo: ColorRgb,
fuzz: f32,

pub fn init(albedo: ColorRgb, fuzz: f32) Self {
    const fuzzyness = @min(1, fuzz);

    return .{
        .albedo = albedo,
        .fuzz = fuzzyness,
    };
}

pub fn scatter(
    self: *const Self,
    rand: *Random,
    ray: *const Ray,
    hit_record: *const Ray.HitRecord,
) !?Ray.ScatterRay {
    const reflected_ray: Vec3f = tools.reflectVector(ray.*.direction, hit_record.*.normal);

    const fuzzy_ray = (try reflected_ray.unit()).addVec(
        tools.randomUnitVector(rand).multiply(self.fuzz),
    );

    const scatter_ray = try Ray.init(hit_record.*.point, fuzzy_ray);

    if (scatter_ray.direction.dot(hit_record.*.normal) <= 0) {
        // absorb ray
        return null;
    }

    return .{
        .ray = scatter_ray,
        .attenuation = self.albedo,
    };
}
