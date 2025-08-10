const std = @import("std");
const lib = @import("zulkray_lib");

const Vec3f = lib.Vec3f;
const Point3 = lib.Point3;
const ColorRgb = lib.ColorRgb;

const Camera = lib.Camera;
const Material = lib.Material;
const Object = lib.World.Object;
const Sphere = lib.Sphere;
const World = lib.World;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    var world = World.init(allocator);
    defer world.deinit();

    // ground
    try world.append(Object{
        .Sphere = try Sphere.init(
            Point3.init(.{ 0.0, -100.5, -1.0 }),
            100,
            &.{ .Lambertian = .init(ColorRgb.init(.{ 0.8, 0.8, 0.0 })) },
        ),
    });
    // lambertian center
    try world.append(Object{
        .Sphere = try Sphere.init(
            Point3.init(.{ 0.0, 0.0, -1.2 }),
            0.5,
            &.{ .Lambertian = .init(ColorRgb.init(.{ 0.1, 0.2, 0.5 })) },
        ),
    });
    // outer glass left
    try world.append(Object{
        .Sphere = try Sphere.init(
            Point3.init(.{ -1.0, 0.0, -1.0 }),
            0.5,
            &.{ .Dielectric = .init(1.5) },
        ),
    });
    // inner air bubble left
    try world.append(Object{
        .Sphere = try Sphere.init(
            Point3.init(.{ -1.0, 0.0, -1.0 }),
            0.4,
            &.{ .Dielectric = .init(1.0 / 1.5) },
        ),
    });
    // fuzzy metal right
    try world.append(Object{
        .Sphere = try Sphere.init(
            Point3.init(.{ 1.0, 0.0, -1.0 }),
            0.5,
            &.{ .Metal = .init(ColorRgb.init(.{ 0.8, 0.6, 0.2 }), 1.0) },
        ),
    });

    const camera = try Camera.init(
        400,
        16.0 / 9.0,
        20.0,
        Point3.init(.{ -2.0, 2.0, 1.0 }),
        Point3.init(.{ 0.0, 0.0, -1.0 }),
        Vec3f.init(.{ 0.0, 1.0, 0.0 }),
        100,
        50,
    );

    const stdout = std.io.getStdOut();

    try lib.exportAsPpm(
        &stdout,
        &world,
        &camera,
        null,
    );
}
