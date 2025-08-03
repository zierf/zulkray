const std = @import("std");
const File = std.fs.File;

pub const vector = @import("vector.zig");

pub const Camera = @import("Camera.zig");
pub const Ray = @import("Ray.zig");
pub const Sphere = @import("objects/Sphere.zig");
pub const World = @import("World.zig");

const Interval = @import("Interval.zig");

pub const Vec3f = vector.Vec3f;
pub const Point3 = vector.Point3;

const ColorRgb = vector.ColorRgb;

const color_black = ColorRgb.init(.{ 0.0, 0.0, 0.0 });

pub fn exportAsPpm(
    file: *const File,
    world: *const World,
    camera: *const Camera,
    binary: ?bool,
) !void {
    const is_binary = binary orelse true;

    // track progress
    const progress_root = std.Progress.start(.{
        .root_name = "Rendering Scene …",
    });

    const sub_node = progress_root.start("rendered rows", camera.image_height);
    defer sub_node.end();

    // prepare file writer
    var buffered_writer = std.io.bufferedWriter(file.writer());
    const file_writer = buffered_writer.writer();

    // write PPM header
    const image_format = if (is_binary) "P6" else "P3";

    try file_writer.print("{s}\n{} {}\n255\n", .{
        image_format,
        camera.image_width,
        camera.image_height,
    });

    // write image contents
    for (0..camera.image_height) |row| {
        for (0..camera.image_width) |column| {
            const pixel_u = camera.pixel_delta_u.multiply(@floatFromInt(column));
            const pixel_v = camera.pixel_delta_v.multiply(@floatFromInt(row));

            // vector for pixel_upper_left points to first pixel center
            const pixel_center = camera.pixel_upper_left.addVec(pixel_u).addVec(pixel_v);
            const ray_direction = pixel_center.subtractVec(camera.center);

            const pixel_ray = try Ray.init(camera.center, ray_direction);
            const color: ColorRgb = world.rayColor(&pixel_ray) catch color_black;

            // fill with a red-green-yellow gradient, left->right: red, top->bottom: green
            // const color: ColorRgb = .init(.{
            //     @as(f32, @floatFromInt(column)) / @as(f32, @floatFromInt(camera.image_width - 1)),
            //     @as(f32, @floatFromInt(row)) / @as(f32, @floatFromInt(camera.image_height - 1)),
            //     0.0,
            // });

            if (is_binary) {
                try file_writer.writeByte(color.rByte());
                try file_writer.writeByte(color.gByte());
                try file_writer.writeByte(color.bByte());
            } else {
                try file_writer.print("{: >3} {: >3} {: >3}\n", .{
                    color.rByte(),
                    color.gByte(),
                    color.bByte(),
                });
            }
        }

        sub_node.completeOne();
        // std.Thread.sleep(10 * 1_000_000);
    }

    // flush writer to write all data
    try buffered_writer.flush();
}

test {
    std.testing.refAllDecls(@This());
    // _ = &vector;
}
