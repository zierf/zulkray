const vector = @import("vector.zig");
const material = @import("materials/material.zig");

const Vec3f = vector.Vec3f;
const Point3 = vector.Point3;
const ColorRgb = vector.ColorRgb;
const Material = material.Material;

const Self = @This();
const ElementType = Vec3f.elementType();

pub const RayError = error{
    RayWithoutDirection,
};

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

pub const HitRecord = struct {
    point: Point3,
    normal: Vec3f,
    distance: f32,
    is_front_face: bool,
    material: *const Material,

    pub fn hasOutwardNormal(self: *const HitRecord, ray: *const Self) bool {
        return ray.direction.dot(self.normal) < 0.0;
    }
};

pub const ScatterRay = struct {
    ray: Self,
    attenuation: ColorRgb,
};
