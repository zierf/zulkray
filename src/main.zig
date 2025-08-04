const std = @import("std");
const lib = @import("zulkray_lib");

const Point3 = lib.Point3;

const Camera = lib.Camera;
const Sphere = lib.Sphere;
const World = lib.World;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    var world = World.init(allocator);
    defer world.deinit();

    try world.append(World.Object{
        .Sphere = try Sphere.init(
            Point3.init(.{ 0.0, 0.0, -1.0 }),
            0.5,
        ),
    });
    try world.append(World.Object{
        .Sphere = try Sphere.init(
            Point3.init(.{ 0.0, -100.5, -1.0 }),
            100,
        ),
    });

    const camera = try Camera.init(
        400,
        16.0 / 9.0,
        2.0,
        Point3.zero(),
        1.0,
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
