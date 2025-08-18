const std = @import("std");
const lib = @import("zulkray_lib");

const sdl = @cImport({
    @cInclude("SDL3/SDL.h");
    @cInclude("SDL3/SDL_vulkan.h");
});

const vk = @cImport({
    @cDefine("VK_NO_PROTOTYPES", {});
    @cInclude("vulkan/vulkan.h");
});

const Random = lib.Random;
const tools = lib.tools;

const Vec3f = lib.Vec3f;
const Point3 = lib.Point3;
const ColorRgb = lib.ColorRgb;

const Camera = lib.Camera;
const MaterialMap = lib.MaterialMap;
const Object = lib.World.Object;
const Sphere = lib.Sphere;
const World = lib.World;

pub const ApplicationError = error{
    SdlInitializationFailed,
    SdlRendererNotFound,
    SdlSurfaceCreationFailed,
    SdlTextureCreationFailed,
    SdlVulkanExtensionsNotFound,
    SdlWindowCreationFailed,
    VulkanInstanceCreationFailed,
};

const show_demo_scene = false;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    var material_map = MaterialMap.init(allocator);
    defer material_map.deinit();

    var world = World.init(allocator);
    defer world.deinit();

    const camera: Camera = blk: {
        if (!show_demo_scene) {
            try createMainScene(&world, &material_map);

            break :blk try Camera.init(
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

            break :blk try Camera.init(
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
    };

    const image_buffer = try allocator.alloc(u8, 3 * camera.image_width * camera.image_height);
    defer allocator.free(image_buffer);

    try lib.renderRgbImage(
        &world,
        &material_map,
        &camera,
        image_buffer,
    );

    // const stdout = std.io.getStdOut();
    const cwd = std.fs.cwd();
    const image_file = try cwd.createFile("image.ppm", std.fs.File.CreateFlags{
        .read = true,
        .truncate = true,
    });

    try lib.exportAsPpm(
        &image_file,
        camera.image_width,
        camera.image_height,
        image_buffer,
        null,
    );

    if (!sdl.SDL_Init(sdl.SDL_INIT_VIDEO)) {
        sdl.SDL_LogError(sdl.SDL_LOG_CATEGORY_APPLICATION, "Could not initialize SDL: %s\n", sdl.SDL_GetError());
        return ApplicationError.SdlInitializationFailed;
    }
    defer sdl.SDL_Quit();

    const sdl_window = sdl.SDL_CreateWindow(
        "Zulkray Raytracer",
        @intCast(camera.image_width),
        @intCast(camera.image_height),
        sdl.SDL_WINDOW_VULKAN,
    ) orelse {
        sdl.SDL_LogError(sdl.SDL_LOG_CATEGORY_APPLICATION, "Could not create window: %s\n", sdl.SDL_GetError());
        return ApplicationError.SdlInitializationFailed;
    };
    defer sdl.SDL_DestroyWindow(sdl_window);

    var count_extensions: u32 = undefined;
    const extensions = sdl.SDL_Vulkan_GetInstanceExtensions(&count_extensions) orelse {
        sdl.SDL_LogError(sdl.SDL_LOG_CATEGORY_APPLICATION, "Retrieving Vulkan extensions failed: %s\n", sdl.SDL_GetError());
        return ApplicationError.SdlVulkanExtensionsNotFound;
    };

    for (0..count_extensions) |index| {
        std.debug.print("SDL vkExtension {}: {s}\n", .{ index, extensions[index] });
    }

    const allocator_callbacks: ?vk.VkAllocationCallbacks = null;

    const vk_insance_proc_addr: vk.PFN_vkGetInstanceProcAddr = @ptrCast(sdl.SDL_Vulkan_GetVkGetInstanceProcAddr());

    const create_instance: vk.PFN_vkCreateInstance = @ptrCast(vk_insance_proc_addr.?(null, "vkCreateInstance"));

    const vulkan_create_info = std.mem.zeroInit(vk.VkInstanceCreateInfo, .{
        .sType = vk.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
        .enabledExtensionCount = count_extensions,
        .ppEnabledExtensionNames = extensions,
    });

    var instance: vk.VkInstance = undefined;

    if (create_instance.?(
        &vulkan_create_info,
        @ptrCast(&allocator_callbacks),
        &instance,
    ) != 0) {
        sdl.SDL_LogError(sdl.SDL_LOG_CATEGORY_APPLICATION, "%s\n", "Could not create Vulkan instance!");
        return ApplicationError.VulkanInstanceCreationFailed;
    }

    var surface: vk.VkSurfaceKHR = undefined;

    if (!sdl.SDL_Vulkan_CreateSurface(
        sdl_window,
        @ptrCast(instance),
        @ptrCast(&allocator_callbacks),
        &surface,
    )) {
        sdl.SDL_LogError(sdl.SDL_LOG_CATEGORY_APPLICATION, "Could not create surface: %s\n", sdl.SDL_GetError());
        return ApplicationError.SdlSurfaceCreationFailed;
    }
    defer sdl.SDL_Vulkan_DestroySurface(
        @ptrCast(instance),
        @ptrCast(surface),
        @ptrCast(&allocator_callbacks),
    );

    // there will be no window on wayland without a renderer
    // see https://github.com/libsdl-org/SDL/issues/7699#issuecomment-1545684792
    // force X11 window with environment variable `SDL_VIDEODRIVER=x11`

    // for (0..@intCast(sdl.SDL_GetNumRenderDrivers())) |index| {
    //     std.debug.print("SDL RenderDriver {}: {s}\n", .{ index, sdl.SDL_GetRenderDriver(@intCast(index)) });
    // }

    const renderer = sdl.SDL_CreateRenderer(sdl_window, "vulkan") orelse {
        sdl.SDL_LogError(sdl.SDL_LOG_CATEGORY_APPLICATION, "Error retrieving renderer: %s\n", sdl.SDL_GetError());
        return ApplicationError.SdlRendererNotFound;
    };
    defer sdl.SDL_DestroyRenderer(renderer);

    const texture = sdl.SDL_CreateTexture(
        renderer,
        sdl.SDL_PIXELFORMAT_RGB24,
        sdl.SDL_TEXTUREACCESS_STATIC,
        @intCast(camera.image_width),
        @intCast(camera.image_height),
    ) orelse {
        sdl.SDL_LogError(sdl.SDL_LOG_CATEGORY_APPLICATION, "Could not create texture: %s\n", sdl.SDL_GetError());
        return ApplicationError.SdlTextureCreationFailed;
    };

    _ = sdl.SDL_UpdateTexture(
        texture,
        null,
        @ptrCast(image_buffer),
        @intCast(camera.image_width * 3),
    );

    while (true) {
        // handle events
        var event: sdl.SDL_Event = undefined;
        _ = sdl.SDL_PollEvent(&event);

        switch (event.type) {
            sdl.SDL_EVENT_QUIT => break,
            sdl.SDL_EVENT_KEY_DOWN => {
                if (event.key.scancode == sdl.SDL_SCANCODE_ESCAPE) {
                    break;
                }

                if (event.key.key == sdl.SDLK_S) {
                    const screenshot = sdl.SDL_RenderReadPixels(renderer, null);

                    if (screenshot == null) {
                        sdl.SDL_LogError(sdl.SDL_LOG_CATEGORY_APPLICATION, "Could not create screenshot: %s\n", sdl.SDL_GetError());
                        continue;
                    }

                    if (!sdl.SDL_SaveBMP(screenshot, "screenshot.bmp")) {
                        sdl.SDL_LogError(sdl.SDL_LOG_CATEGORY_APPLICATION, "Could not save screenshot: %s\n", sdl.SDL_GetError());
                    }

                    sdl.SDL_DestroySurface(screenshot);
                }
            },
            else => {},
        }

        // render loop
        _ = sdl.SDL_SetRenderDrawColorFloat(renderer, 0.0, 0.0, 0.0, 1.0);
        _ = sdl.SDL_RenderClear(renderer);
        _ = sdl.SDL_RenderTexture(renderer, texture, null, null);
        _ = sdl.SDL_RenderPresent(renderer);
    }
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

            if (sphere_center.subtractVec(&Point3.init(.{ 4.0, 0.2, 0.0 })).length() > 0.9) {
                const choose_mat = rand.float();

                if (choose_mat < 0.8) {
                    const albedo = tools.randomVector(&rand).multiplyVecComponents(
                        &tools.randomVector(&rand),
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
