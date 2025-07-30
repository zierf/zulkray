const std = @import("std");
const lib = @import("zulkray_lib");

const image_width: u32 = 256;
const image_height: u32 = 256;

pub fn main() !void {
    const stdout = std.io.getStdOut();

    try lib.exportAsPpm(&stdout, image_width, image_height, null);
}
