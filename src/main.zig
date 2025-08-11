const std = @import("std");
const lib = @import("zulkray_lib");

const Allocator = std.mem.Allocator;

const Random = lib.Random;
const tools = lib.tools;

const Vec3f = lib.Vec3f;
const Point3 = lib.Point3;
const ColorRgb = lib.ColorRgb;

const Camera = lib.Camera;
const Material = lib.Material;
const MaterialMap = lib.MaterialMap;
const Object = lib.World.Object;
const Sphere = lib.Sphere;
const World = lib.World;

const show_demo_scene = true;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    var material_map = MaterialMap.init(allocator);
    defer material_map.deinit();

    var world = World.init(allocator);
    defer world.deinit();

    var camera: Camera = undefined;

    if (!show_demo_scene) {
        try createMainScene(&world, &material_map);

        camera = try Camera.init(
            400,
            16.0 / 9.0,
            20.0,
            Point3.init(.{ -2.0, 2.0, 1.0 }),
            Point3.init(.{ 0.0, 0.0, -1.0 }),
            Vec3f.init(.{ 0.0, 1.0, 0.0 }),
            3.4,
            10.0,
            100,
            50,
        );
    } else {
        try createDemoScene(&world, &material_map);

        camera = try Camera.init(
            400, // 1200,
            16.0 / 9.0,
            20.0,
            Point3.init(.{ 13.0, 2.0, 3.0 }),
            Point3.init(.{ 0.0, 0.0, 0.0 }),
            Vec3f.init(.{ 0.0, 1.0, 0.0 }),
            10.0,
            0.6,
            50, // 500,
            5, // 50,
        );
    }

    const stdout = std.io.getStdOut();

    try lib.exportAsPpm(
        &stdout,
        &world,
        &material_map,
        &camera,
        null,
    );
}

fn createMainScene(
    world: *World,
    material_map: *MaterialMap,
) !void {
    const material_ground = try material_map.*.add(
        "ground",
        .{ .Lambertian = .init(ColorRgb.init(.{ 0.8, 0.8, 0.0 })) },
    );
    const material_diffuse = try material_map.*.add(
        "diffuse",
        .{ .Lambertian = .init(ColorRgb.init(.{ 0.1, 0.2, 0.5 })) },
    );
    const material_outer_glass = try material_map.*.add(
        "outer_glass",
        .{ .Dielectric = .init(1.5) },
    );
    const material_inner_air = try material_map.*.add(
        "inner_air",
        .{ .Dielectric = .init(1.0 / 1.5) },
    );
    const material_fuzzy_metal = try material_map.*.add(
        "fuzzy_metal",
        .{ .Metal = .init(ColorRgb.init(.{ 0.8, 0.6, 0.2 }), 1.0) },
    );

    // ground
    try world.append(Object{
        .Sphere = try Sphere.init(
            Point3.init(.{ 0.0, -100.5, -1.0 }),
            100.0,
            material_ground,
        ),
    });
    // lambertian center
    try world.append(Object{
        .Sphere = try Sphere.init(
            Point3.init(.{ 0.0, 0.0, -1.2 }),
            0.5,
            material_diffuse,
        ),
    });
    // outer glass left
    try world.append(Object{
        .Sphere = try Sphere.init(
            Point3.init(.{ -1.0, 0.0, -1.0 }),
            0.5,
            material_outer_glass,
        ),
    });
    // inner air bubble left
    try world.append(Object{
        .Sphere = try Sphere.init(
            Point3.init(.{ -1.0, 0.0, -1.0 }),
            0.4,
            material_inner_air,
        ),
    });
    // fuzzy metal right
    try world.append(Object{
        .Sphere = try Sphere.init(
            Point3.init(.{ 1.0, 0.0, -1.0 }),
            0.5,
            material_fuzzy_metal,
        ),
    });
}

fn createDemoScene(
    world: *World,
    material_map: *MaterialMap,
) !void {
    var rand = Random.init(null);

    const material_ground = try material_map.*.add(
        "ground",
        .{ .Lambertian = .init(ColorRgb.init(.{ 0.5, 0.5, 0.5 })) },
    );

    // ground
    try world.append(Object{
        .Sphere = try Sphere.init(
            Point3.init(.{ 0.0, -1000.0, 0.0 }),
            1000.0,
            material_ground,
        ),
    });

    const material_glass_small = try material_map.*.add(
        "glass_small",
        .{ .Dielectric = .init(1.5) },
    );

    var name_buffer: [20]u8 = undefined;

    const spheres_xy = 22;

    for (0..spheres_xy) |a| {
        for (0..spheres_xy) |b| {
            const a_float: f32 = @floatFromInt(a);
            const b_float: f32 = @floatFromInt(b);

            const sphere_center = Point3.init(.{
                (a_float - (spheres_xy / 2.0)) + (0.9 * rand.float()),
                0.2,
                (b_float - (spheres_xy / 2.0)) + (0.9 * rand.float()),
            });

            if (sphere_center.subtractVec(Point3.init(.{ 4.0, 0.2, 0.0 })).length() > 0.9) {
                const choose_mat = rand.float();

                if (choose_mat < 0.8) {
                    const albedo = tools.randomVector(&rand).multiplyVecComponents(
                        tools.randomVector(&rand),
                    );

                    // don't use this as key for the sphere material, it will go out of scope
                    const tmp_material_key = try std.fmt.bufPrint(
                        &name_buffer,
                        "diffuse_small_{}{}",
                        .{ a, b },
                    );

                    const material_diffuse_small = try material_map.*.add(
                        tmp_material_key,
                        .{ .Lambertian = .init(albedo) },
                    );

                    // diffuse
                    try world.append(Object{
                        .Sphere = try Sphere.init(
                            sphere_center,
                            0.2,
                            // use owned key returned by the add(…) function (or a string with static lifetime)
                            material_diffuse_small,
                        ),
                    });
                } else if (choose_mat < 0.95) {
                    const albedo = tools.randomVectorBetween(&rand, 0.5, 1.0);
                    const fuzz = rand.floatBetween(0.0, 0.5);

                    // don't use this as key for the sphere material, it will go out of scope
                    const tmp_material_key = try std.fmt.bufPrint(
                        &name_buffer,
                        "diffuse_small_{}{}",
                        .{ a, b },
                    );

                    const material_metal_small = try material_map.*.add(
                        tmp_material_key,
                        .{ .Metal = .init(albedo, fuzz) },
                    );

                    // metal
                    try world.append(Object{
                        .Sphere = try Sphere.init(
                            sphere_center,
                            0.2,
                            // use owned key returned by the add(…) function (or a string with static lifetime)
                            material_metal_small,
                        ),
                    });
                } else {
                    // glass
                    try world.append(Object{
                        .Sphere = try Sphere.init(
                            sphere_center,
                            0.2,
                            material_glass_small,
                        ),
                    });
                }
            }
        }
    }

    const material_glass = try material_map.*.add(
        "glass",
        .{ .Dielectric = .init(1.5) },
    );
    const material_diffuse = try material_map.*.add(
        "diffuse",
        .{ .Lambertian = .init(ColorRgb.init(.{ 0.4, 0.2, 0.1 })) },
    );
    const material_metal = try material_map.*.add(
        "metal",
        .{ .Metal = .init(ColorRgb.init(.{ 0.7, 0.6, 0.5 }), 0.0) },
    );

    // glass
    try world.append(Object{
        .Sphere = try Sphere.init(
            Point3.init(.{ 0.0, 1.0, 0.0 }),
            1.0,
            material_glass,
        ),
    });
    // lambertian
    try world.append(Object{
        .Sphere = try Sphere.init(
            Point3.init(.{ -4.0, 1.0, 0.0 }),
            1.0,
            material_diffuse,
        ),
    });
    // metal
    try world.append(Object{
        .Sphere = try Sphere.init(
            Point3.init(.{ 4.0, 1.0, 0.0 }),
            1.0,
            material_metal,
        ),
    });
}
