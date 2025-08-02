const vector = @import("vector.zig");

const Vec3f = vector.Vec3f;
const Point3 = vector.Point3;

pub const Camera = struct {
    const Self = @This();

    focal_length: f32,
    camera_center: Point3,

    pixel_delta_u: Vec3f,
    pixel_delta_v: Vec3f,

    pixel_upper_left: Vec3f,

    pub fn init(image_width: u32, image_height: u32, focal_length: f32) !Self {
        const camera_center = Point3.zero();

        const image_width_float: f32 = @floatFromInt(image_width);
        const image_height_float: f32 = @floatFromInt(image_height);

        const viewport_height: f32 = 2.0;
        // viewport is real valued, width less than one is ok here
        const viewport_width: f32 = viewport_height * (image_width_float / image_height_float);

        // calculate the vectors across the horizontal and down the vertical viewport edges
        const viewport_u: Vec3f = .init(.{ viewport_width, 0, 0 });
        const viewport_v: Vec3f = .init(.{ 0, -viewport_height, 0 });

        // calculate the horizontal and vertical delta vectors from pixel to pixel
        const pixel_delta_u = try viewport_u.divide(@floatFromInt(image_width));
        const pixel_delta_v = try viewport_v.divide(@floatFromInt(image_height));

        // calculate focal plane
        const camera_to_focal: Vec3f = .init(.{ 0, 0, -focal_length });
        const focal_plane = camera_center.addVec(camera_to_focal);

        // calculate the location of the upper left pixel
        const viewport_upper_left = focal_plane
            .subtractVec(try viewport_u.divide(2))
            .subtractVec(try viewport_v.divide(2));
        const pixel_delta_center = pixel_delta_u.addVec(pixel_delta_v).multiply(0.5);
        const pixel_upper_left = viewport_upper_left.addVec(pixel_delta_center);

        return .{
            .focal_length = focal_length,
            .camera_center = camera_center,

            .pixel_delta_u = pixel_delta_u,
            .pixel_delta_v = pixel_delta_v,

            .pixel_upper_left = pixel_upper_left,
        };
    }
};
