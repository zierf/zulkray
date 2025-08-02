const std = @import("std");
const lib = @import("zulkray_lib");

const Point3 = lib.Point3;

const Camera = lib.camera.Camera;
const Sphere = lib.Sphere;
const World = lib.World;

const aspect_ratio: f32 = 16.0 / 9.0;

const image_width: u32 = @max(1, 400);
// image height based on width and aspect ratio, but at least one pixel
const image_height: u32 = @max(1, image_width / aspect_ratio);

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    var world = World.init(allocator);
    defer world.deinit();

    try world.append(try Sphere.init(Point3.init(.{ 0.0, 0.0, -1.0 }), 0.5));
    try world.append(try Sphere.init(Point3.init(.{ 0.0, -100.5, -1.0 }), 100));

    const camera = try Camera.init(
        image_width,
        image_height,
        1.0,
    );

    const stdout = std.io.getStdOut();

    try lib.exportAsPpm(
        &stdout,
        image_width,
        image_height,
        &world,
        &camera,
        null,
    );
}
