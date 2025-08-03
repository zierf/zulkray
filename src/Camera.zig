const std = @import("std");

const vector = @import("vector.zig");
const Interval = @import("Interval.zig");
const Ray = @import("Ray.zig");
const World = @import("World.zig");
const tools = @import("tools.zig");

const Vec3f = vector.Vec3f;
const Point3 = vector.Point3;
const ColorRgb = vector.ColorRgb;

const Self = @This();

pub const CameraError = error{
    RenderOutsideImageDimensions,
};

image_width: usize,
image_height: usize,

focal_length: f32,
center: Point3,

pixel_delta_u: Vec3f,
pixel_delta_v: Vec3f,

pixel_upper_left: Vec3f,

const color_black = ColorRgb.init(.{ 0.0, 0.0, 0.0 });

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

pub fn renderAt(self: *const Self, world: *const World, row: usize, column: usize) !ColorRgb {
    if (row > self.image_height or column > self.image_width) {
        return CameraError.RenderOutsideImageDimensions;
    }

    const pixel_u = self.pixel_delta_u.multiply(@floatFromInt(column));
    const pixel_v = self.pixel_delta_v.multiply(@floatFromInt(row));

    // vector for pixel_upper_left points to first pixel center
    const pixel_center = self.pixel_upper_left.addVec(pixel_u).addVec(pixel_v);
    const ray_direction = pixel_center.subtractVec(self.center);

    const pixel_ray = try Ray.init(self.center, ray_direction);
    const color: ColorRgb = rayColor(world, &pixel_ray) catch color_black;

    // // fill with a red-green-yellow gradient, left->right: red, top->bottom: green
    // const color: ColorRgb = .init(.{
    //     @as(f32, @floatFromInt(column)) / @as(f32, @floatFromInt(self.image_width - 1)),
    //     @as(f32, @floatFromInt(row)) / @as(f32, @floatFromInt(self.image_height - 1)),
    //     0.0,
    // });

    return color;
}

fn rayColor(world: *const World, ray: *const Ray) !ColorRgb {
    const ray_limits = try Interval.init(0, std.math.inf(f32));

    if (try world.hitAnything(ray, &ray_limits)) |*hit_record| {
        // each component of unit vector is between [−1,1], map to color from [0,1]
        const normal_color: ColorRgb = hit_record.*.normal.add(1.0).multiply(0.5);
        return normal_color;
    }

    // render background color, needs unit vector
    const unit_direction: Vec3f = ray.direction.unit() catch unreachable;

    // define color based on a bluish->white interpolated gradient from top to bottom
    const percentage = 0.5 * (unit_direction.y() + 1.0);

    return tools.lerpVector(
        percentage,
        ColorRgb.init(.{ 1.0, 1.0, 1.0 }),
        ColorRgb.init(.{ 0.5, 0.7, 1.0 }),
    );
}
