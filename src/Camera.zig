const vector = @import("vector.zig");

const Vec3f = vector.Vec3f;
const Point3 = vector.Point3;

const Self = @This();

image_width: usize,
image_height: usize,

focal_length: f32,
center: Point3,

pixel_delta_u: Vec3f,
pixel_delta_v: Vec3f,

pixel_upper_left: Vec3f,

pub fn init(
    image_width: usize,
    aspect_ratio: f32,
    viewport_height: f32,
    center: Point3,
    focal_length: f32,
) !Self {
    const image_width_float: f32 = @floatFromInt(image_width);
    const image_height_float: f32 = image_width_float / aspect_ratio;

    const image_height: usize = @max(
        1,
        @as(usize, @intFromFloat(image_height_float)),
    );

    // viewport is real valued, width less than one is ok here
    const viewport_width: f32 = viewport_height * (image_width_float / image_height_float);

    // calculate the vectors across the horizontal and down the vertical viewport edges
    const viewport_u: Vec3f = .init(.{ viewport_width, 0, 0 });
    const viewport_v: Vec3f = .init(.{ 0, -viewport_height, 0 });

    // calculate the horizontal and vertical delta vectors from pixel to pixel
    const pixel_delta_u = try viewport_u.divide(@floatFromInt(image_width));
    const pixel_delta_v = try viewport_v.divide(@floatFromInt(image_height));

    // calculate vector to focal plane
    const focal_relative: Vec3f = .init(.{ 0, 0, -focal_length });
    const camera_to_focal = center.addVec(focal_relative);

    // calculate the location of the upper left pixel
    const viewport_upper_left = camera_to_focal
        .subtractVec(try viewport_u.divide(2))
        .subtractVec(try viewport_v.divide(2));
    const pixel_delta_center = pixel_delta_u.addVec(pixel_delta_v).multiply(0.5);
    const pixel_upper_left = viewport_upper_left.addVec(pixel_delta_center);

    return .{
        .image_width = image_width,
        .image_height = image_height,

        .focal_length = focal_length,
        .center = center,

        .pixel_delta_u = pixel_delta_u,
        .pixel_delta_v = pixel_delta_v,

        .pixel_upper_left = pixel_upper_left,
    };
}
