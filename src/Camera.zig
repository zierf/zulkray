const std = @import("std");

const vector = @import("vector.zig");
const Interval = @import("Interval.zig");
const Random = @import("Random.zig");
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
vfov: f32,
look_from: Point3,
look_at: Point3,
view_up: Vec3f,

samples: usize,
bounces: usize,

pixel_delta_u: Vec3f,
pixel_delta_v: Vec3f,

pixel_upper_left: Vec3f,

rand: *Random,

const color_black = ColorRgb.init(.{ 0.0, 0.0, 0.0 });

pub fn init(
    image_width: usize,
    aspect_ratio: f32,
    vfov: f32,
    look_from: Point3,
    look_at: Point3,
    view_up: Vec3f,
    samples: usize,
    bounces: usize,
) !Self {
    const image_width_float: f32 = @floatFromInt(image_width);
    const image_height_float: f32 = image_width_float / aspect_ratio;

    const image_height: usize = @max(
        1,
        @as(usize, @intFromFloat(image_height_float)),
    );

    // determine viewport dimensions
    const focal_length = look_at.subtractVec(look_from).length();
    const theta = std.math.degreesToRadians(vfov);
    const vfov_height = std.math.tan(theta / 2.0);

    const viewport_height = 2 * vfov_height * focal_length;
    // viewport is real valued, width less than one is ok here
    const viewport_width: f32 = viewport_height * (image_width_float / image_height_float);

    // calculate the u,v,w (camera_right,camera_up,view_opposite) unit basis vectors for the camera coordinate frame
    const view_opposite = try look_at.subtractVec(look_from).negate().unit();
    const camera_right = try view_up.cross(view_opposite).unit();
    const camera_up = view_opposite.cross(camera_right);

    // calculate the vectors across the horizontal and down the vertical viewport edges
    const viewport_u: Vec3f = camera_right.multiply(viewport_width);
    const viewport_v: Vec3f = camera_up.negate().multiply(viewport_height);

    // calculate the horizontal and vertical delta vectors from pixel to pixel
    const pixel_delta_u = try viewport_u.divide(@floatFromInt(image_width));
    const pixel_delta_v = try viewport_v.divide(@floatFromInt(image_height));

    // calculate vector to focal plane
    const camera_to_focal_plane: Vec3f = look_from.subtractVec(
        view_opposite.multiply(focal_length),
    );

    // calculate the location of the upper left pixel
    const viewport_upper_left = camera_to_focal_plane
        .subtractVec(try viewport_u.divide(2))
        .subtractVec(try viewport_v.divide(2));

    const pixel_delta_center = pixel_delta_u.addVec(pixel_delta_v).multiply(0.5);
    const pixel_upper_left = viewport_upper_left.addVec(pixel_delta_center);

    var random_generator = Random.init(null);

    return .{
        .image_width = image_width,
        .image_height = image_height,

        .focal_length = focal_length,
        .vfov = vfov,

        .look_from = look_from,
        .look_at = look_at,
        .view_up = view_up,

        .samples = samples,
        .bounces = bounces,

        .pixel_delta_u = pixel_delta_u,
        .pixel_delta_v = pixel_delta_v,

        .pixel_upper_left = pixel_upper_left,

        .rand = &random_generator,
    };
}

pub fn renderAt(self: *const Self, world: *const World, row: usize, column: usize) !ColorRgb {
    if (row > self.image_height or column > self.image_width) {
        return CameraError.RenderOutsideImageDimensions;
    }

    var color: ColorRgb = ColorRgb.zero();

    // add up all the samples
    for (0..self.samples) |_| {
        const ray = try self.getRay(row, column);

        color = color.addVec(
            self.rayColor(world, &ray, self.bounces) catch color_black,
        );
    }

    // get the average color of all the samples
    color = color.multiply(
        1.0 / @as(f32, @floatFromInt(self.samples)),
    );

    // convert color from linear space to gamma space
    color = try tools.linearToGammaSpace(color);

    // fill viewport with a red-green-yellow gradient, left->right: red, top->bottom: green
    // const color: ColorRgb = .init(.{
    //     @as(f32, @floatFromInt(column)) / @as(f32, @floatFromInt(self.image_width - 1)),
    //     @as(f32, @floatFromInt(row)) / @as(f32, @floatFromInt(self.image_height - 1)),
    //     0.0,
    // });

    return color;
}

/// Construct a camera ray originating from the origin
/// and directed at randomly sampled point around the pixel location
/// at row and column.
fn getRay(self: *const Self, row: usize, column: usize) !Ray {
    const offset: Vec3f = tools.pixelSampleSquare(self.rand);

    // vector for pixel_upper_left points to first pixel center
    // plus a small offset in the pixel square.
    const pixel_sample = self.pixel_upper_left
        .addVec(self.pixel_delta_u.multiply(@as(f32, @floatFromInt(column)) + offset.x()))
        .addVec(self.pixel_delta_v.multiply(@as(f32, @floatFromInt(row)) + offset.y()));

    const ray_origin: Point3 = self.look_from;
    const ray_direction: Vec3f = pixel_sample.subtractVec(ray_origin);

    return try Ray.init(ray_origin, ray_direction);
}

fn rayColor(self: *const Self, world: *const World, ray: *const Ray, bounces: usize) !ColorRgb {
    // stop light collection after reaching the limit for ray bounces
    if (bounces <= 0) {
        return color_black;
    }

    // choose a lower limit that avoids collision with the same surface after rounding errors
    const ray_limits = try Interval.init(0.001, std.math.inf(f32));

    if (try world.hitAnything(ray, &ray_limits)) |*hit_record| {
        // render normal colors: each component of unit vector is between [−1,1], map to color from [0,1]
        // _ = self;
        // const normal_color: ColorRgb = hit_record.*.normal.add(1.0).multiply(0.5);
        // return normal_color;

        const scatter_ray = try hit_record.*.material.*.scatter(
            self.rand,
            ray,
            hit_record,
        );

        if (scatter_ray == null) {
            // ray absorbed
            return color_black;
        }

        const attenuation: ColorRgb = scatter_ray.?.attenuation;
        const color: ColorRgb = try self.rayColor(world, &scatter_ray.?.ray, bounces - 1);

        return attenuation.multiplyVecComponents(color);
    }

    // render background color, needs unit vector
    const unit_direction: Vec3f = ray.*.direction.unit() catch unreachable;

    // define color based on a bluish->white interpolated gradient from top to bottom
    const percentage = 0.5 * (unit_direction.y() + 1.0);

    return tools.lerpVector(
        percentage,
        ColorRgb.init(.{ 1.0, 1.0, 1.0 }),
        ColorRgb.init(.{ 0.5, 0.7, 1.0 }),
    );
}
