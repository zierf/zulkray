const std = @import("std");
const File = std.fs.File;

pub const vector = @import("vector.zig");

pub const Vec3f = vector.Vec3f;
pub const ColorRgb = vector.ColorRgb;

pub fn exportAsPpm(file: *const File, width: u32, height: u32, binary: ?bool) !void {
    const is_binary = binary orelse true;

    // track progress
    const progress_root = std.Progress.start(.{
        .root_name = "Rendering Scene …",
    });

    const sub_node = progress_root.start("rendered rows", height);
    defer sub_node.end();

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

    // write image contents
    for (0..height) |row| {
        for (0..width) |column| {
            const color: ColorRgb = .init(.{
                @as(f32, @floatFromInt(column)) / @as(f32, @floatFromInt(width - 1)),
                @as(f32, @floatFromInt(row)) / @as(f32, @floatFromInt(height - 1)),
                0.0,
            });

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
