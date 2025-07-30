const std = @import("std");
const File = std.fs.File;

pub fn exportAsPpm(file: *const File, image_width: u32, image_height: u32, binary: ?bool) !void {
    const is_binary = binary orelse true;

    // track progress
    const progress_root = std.Progress.start(.{
        .root_name = "Rendering Scene …",
    });

    const sub_node = progress_root.start("rendered rows", image_height);
    defer sub_node.end();

    // prepare file writer
    var buffered_writer = std.io.bufferedWriter(file.writer());
    const file_writer = buffered_writer.writer();

    // write PPM header
    const image_format = if (is_binary) "P6" else "P3";

    try file_writer.print("{s}\n{} {}\n255\n", .{
        image_format,
        image_width,
        image_height,
    });

    // write image contents
    for (0..image_height) |height| {
        for (0..image_width) |width| {
            const r: f32 = @as(f32, @floatFromInt(width)) / @as(f32, @floatFromInt(image_width - 1));
            const g: f32 = @as(f32, @floatFromInt(height)) / @as(f32, @floatFromInt(image_height - 1));
            const b: f32 = 0.0;

            const ir: u8 = @intFromFloat(255.999 * r);
            const ig: u8 = @intFromFloat(255.999 * g);
            const ib: u8 = @intFromFloat(255.999 * b);

            if (is_binary) {
                try file_writer.writeByte(ir);
                try file_writer.writeByte(ig);
                try file_writer.writeByte(ib);
            } else {
                try file_writer.print("{: >3} {: >3} {: >3}\n", .{
                    ir,
                    ig,
                    ib,
                });
            }
        }

        sub_node.completeOne();
        // std.Thread.sleep(10 * 1_000_000);
    }

    // flush writer to write all data
    try buffered_writer.flush();
}
