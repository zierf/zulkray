const std = @import("std");

const Interval = @import("Interval.zig");
const Ray = @import("Ray.zig");
const Sphere = @import("objects/Sphere.zig");

const ArrayList = std.ArrayList;

const Self = @This();

pub const Object = union(enum) {
    Sphere: Sphere,
};

objects: ArrayList(Object),

pub fn init(allocator: std.mem.Allocator) Self {
    return .{
        .objects = ArrayList(Object).init(allocator),
    };
}

pub fn deinit(self: *const Self) void {
    self.objects.deinit();
}

pub fn clear(self: *const Self) void {
    self.objects.clearAndFree();
}

pub fn append(self: *Self, object: Object) !void {
    try self.objects.append(object);
}

pub fn hitAnything(self: *const Self, ray: *const Ray, ray_limits: *const Interval) !?Ray.HitRecord {
    var hit_anything: ?Ray.HitRecord = null;
    var closest_distance: f32 = ray_limits.max;

    for (self.objects.items) |*object| {
        const limits = try Interval.init(ray_limits.min, closest_distance);

        // see [Tagged Unions](https://zig.news/perky/anytype-antics-2398)
        switch (object.*) {
            inline else => |*obj| {
                if (obj.*.hit(ray, &limits)) |hit_record| {
                    closest_distance = hit_record.distance;
                    hit_anything = hit_record;
                }
            },
        }
    }

    return hit_anything;
}
