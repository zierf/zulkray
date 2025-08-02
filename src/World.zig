const std = @import("std");

const tools = @import("tools.zig");
const vector = @import("vector.zig");
const Interval = @import("Interval.zig");
const Ray = @import("Ray.zig");
const Sphere = @import("objects/Sphere.zig");

const ArrayList = std.ArrayList;

const Vec3f = vector.Vec3f;
const ColorRgb = vector.ColorRgb;

const Self = @This();

objects: ArrayList(Sphere),

pub fn init(allocator: std.mem.Allocator) Self {
    return .{
        .objects = ArrayList(Sphere).init(allocator),
    };
}

pub fn deinit(self: *const Self) void {
    self.objects.deinit();
}

pub fn clear(self: *const Self) void {
    self.objects.clearAndFree();
}

pub fn append(self: *Self, object: Sphere) !void {
    try self.objects.append(object);
}

pub fn hitAnything(self: *const Self, ray: *const Ray, ray_limits: *const Interval) !?Ray.HitRecord {
    var hit_anything: ?Ray.HitRecord = null;
    var closest_distance: f32 = ray_limits.max;

    for (self.objects.items) |*object| {
        const limits = try Interval.init(ray_limits.min, closest_distance);

        if (object.*.hit(
            ray,
            &limits,
        )) |hit_record| {
            closest_distance = hit_record.distance;
            hit_anything = hit_record;
        }
    }

    return hit_anything;
}

pub fn rayColor(self: *const Self, ray: *const Ray) !ColorRgb {
    const ray_limits = try Interval.init(0, std.math.inf(f32));

    if (try self.hitAnything(ray, &ray_limits)) |*hit_record| {
        // each component of unit vector is between [−1,1], map to color from [0,1]
        const normal_color: ColorRgb = hit_record.*.normal.add(1.0).multiply(0.5);
        return normal_color;
    }

    // render background color, needs unit vector
    const unit_direction: Vec3f = ray.direction.unit() catch unreachable;

    // define color based on a bluish->white interpolated gradient from top to bottom
    const percentage = 0.5 * (unit_direction.y() + 1.0);

    return tools.lerpVector(
        percentage,
        ColorRgb.init(.{ 1.0, 1.0, 1.0 }),
        ColorRgb.init(.{ 0.5, 0.7, 1.0 }),
    );
}
