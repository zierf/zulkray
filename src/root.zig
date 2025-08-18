const std = @import("std");
const File = std.fs.File;

pub const render = @import("render.zig");

pub const vector = @import("vector.zig");
pub const Random = @import("Random.zig");
pub const tools = @import("tools.zig");

pub const Camera = @import("Camera.zig");
pub const Sphere = @import("objects/Sphere.zig");
pub const World = @import("World.zig");

pub const material = @import("materials/material.zig");

pub const Vec3f = vector.Vec3f;
pub const Point3 = vector.Point3;
pub const ColorRgb = vector.ColorRgb;
pub const Material = material.Material;
pub const MaterialMap = material.MaterialMap;

pub const RenderError = error{
    ImageBufferTooSmall,
};

pub fn renderRgbImage(
    world: *const World,
    material_map: *const MaterialMap,
    camera: *const Camera,
    image_buffer: []u8,
) !void {
    const color_bytes = ColorRgb.dimension;

    // buffer size must be enough to contain 3 byte per pixel
    if (image_buffer.len < (camera.image_width * camera.image_height * color_bytes)) {
        return RenderError.ImageBufferTooSmall;
    }

    for (0..camera.image_height) |row| {
        for (0..camera.image_width) |column| {
            const color: ColorRgb = try camera.renderAt(world, material_map, row, column);

            const color_offset = (row * camera.image_width * color_bytes) + (column * color_bytes);

            image_buffer[color_offset + 0] = color.rByte();
            image_buffer[color_offset + 1] = color.gByte();
            image_buffer[color_offset + 2] = color.bByte();
        }
    }
}

pub fn exportAsPpm(
    file: *const File,
    width: usize,
    height: usize,
    image_buffer: []const u8,
    binary: ?bool,
) !void {
    const color_bytes = ColorRgb.dimension;

    if (image_buffer.len < (width * height * color_bytes)) {
        return RenderError.ImageBufferTooSmall;
    }

    const is_binary = binary orelse true;

    // prepare file writer
    var buffered_writer = std.io.bufferedWriter(file.writer());
    const file_writer = buffered_writer.writer();

    // write PPM header
    const image_format = if (is_binary) "P6" else "P3";

    try file_writer.print("{s}\n{} {}\n255\n", .{
        image_format,
        width,
        height,
    });

    if (is_binary) {
        try file_writer.writeAll(image_buffer);
    } else {
        try file_writer.print("\n", .{});

        for (0..height) |row| {
            for (0..width) |column| {
                const color_offset = (row * width * color_bytes) + (column * color_bytes);

                try file_writer.print("{: >3} {: >3} {: >3}\n", .{
                    image_buffer[color_offset + 0],
                    image_buffer[color_offset + 1],
                    image_buffer[color_offset + 2],
                });
            }

            try file_writer.print("\n", .{});
        }
    }

    // flush writer to write all data
    try buffered_writer.flush();
}

test {
    std.testing.refAllDecls(@This());
    // _ = &vector;
}
