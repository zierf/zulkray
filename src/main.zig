const std = @import("std");
const lib = @import("zulkray_lib");

const image_width: u32 = 256;
const image_height: u32 = 256;

pub fn main() !void {
    const stdout = std.io.getStdOut();

    try lib.exportAsPpm(&stdout, image_width, image_height, null);

    const test_vec: lib.Vec3f = .init(.{ 1.1, 2.2, 3.3 });

    std.debug.print("Vec{}{s} ({} Bytes): {}\n", .{
        @TypeOf(test_vec).dimension(),
        @TypeOf(test_vec).typeName(),
        @TypeOf(test_vec).byteSize(),
        test_vec.vector,
    });

    std.debug.print("Unit Vector: {}\n", .{(try lib.Vec3f.init(.{ 2, 3, 5 }).unit()).length()});

    std.debug.print("Vector color accessors: ({}, {}, {})\n", .{ test_vec.r(), test_vec.g(), test_vec.b() });

    const color: lib.ColorRgb = .init(.{ 1.0, 0.5, 0.0 });
    std.debug.print("Color RGB: ({}, {}, {})\n", .{ color.rByte(), color.gByte(), color.bByte() });

    std.debug.print("Change Dimension: {}\n", .{
        lib.vector.Vec2f.init(.{ 1, 2 }).changeDimension(4, 0),
    });

    std.debug.print("(-3, 6, -3): {}\n", .{lib.Vec3f.init(.{ 2, 3, 4 }).cross(lib.Vec3f.init(.{ 5, 6, 7 }))});

    std.debug.print(
        "a x b = (2 * 1) - (3 * 4) = 2 - 12 = -10: {}\n",
        .{lib.vector.Vec2f.init(.{ 2, 3 }).cross(lib.vector.Vec2f.init(.{ 4, 1 }))},
    );
    std.debug.print(
        "(a, b, 0) x (c, d, 0) = (0, 0, ad - bc): {}\n",
        .{lib.Vec3f.init(.{ 2, 3, 0 }).cross(lib.Vec3f.init(.{ 4, 1, 0 }))},
    );

    const added_vectors = test_vec.addVec(color);
    std.debug.print("Add arbitrary vectors: {}\n", .{added_vectors});
}
