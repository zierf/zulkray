const std = @import("std");

const sdl = @cImport({
    @cInclude("SDL3/SDL.h");
    @cInclude("SDL3/SDL_vulkan.h");
});

const vk = @cImport({
    @cDefine("VK_NO_PROTOTYPES", {});
    @cInclude("vulkan/vulkan.h");
});

pub const ApplicationError = error{
    SdlInitializationFailed,
    SdlRendererNotFound,
    SdlSurfaceCreationFailed,
    SdlTextureCreationFailed,
    SdlVulkanExtensionsNotFound,
    SdlWindowCreationFailed,
    VulkanInstanceCreationFailed,
    VulkanLoadFunctionPointerFailed,
};

pub const SdlWindow = struct {
    const Self = @This();

    window: *sdl.SDL_Window,

    pub fn init(
        window_title: [*c]const u8,
        width: usize,
        height: usize,
    ) !Self {
        if (!sdl.SDL_Init(sdl.SDL_INIT_VIDEO)) {
            logSdlError(
                "Could not initialize SDL: %s\n",
                sdl.SDL_GetError(),
            );
            return ApplicationError.SdlInitializationFailed;
        }

        const sdl_window = sdl.SDL_CreateWindow(
            window_title,
            @intCast(width),
            @intCast(height),
            sdl.SDL_WINDOW_VULKAN,
        ) orelse {
            logSdlError(
                "Could not create window: %s\n",
                sdl.SDL_GetError(),
            );
            return ApplicationError.SdlWindowCreationFailed;
        };

        return .{
            .window = sdl_window,
        };
    }

    pub fn deinit(self: *const Self) void {
        sdl.SDL_DestroyWindow(self.window);
        sdl.SDL_Quit();
    }
};

pub const SdlRenderer = struct {
    const Self = @This();

    sdl_window: *const SdlWindow,
    renderer: *sdl.SDL_Renderer,

    pub fn init(sdl_window: *const SdlWindow) !Self {
        // for (0..@intCast(sdl.SDL_GetNumRenderDrivers())) |index| {
        //     std.debug.print("SDL RenderDriver {}: {s}\n", .{ index, sdl.SDL_GetRenderDriver(@intCast(index)) });
        // }

        // there will be no window on wayland without a renderer
        // see https://github.com/libsdl-org/SDL/issues/7699#issuecomment-1545684792
        // force X11 window with environment variable `SDL_VIDEODRIVER=x11`
        const renderer = sdl.SDL_CreateRenderer(
            sdl_window.window,
            "vulkan",
        ) orelse {
            logSdlError(
                "Error retrieving renderer: %s\n",
                sdl.SDL_GetError(),
            );
            return ApplicationError.SdlRendererNotFound;
        };

        return .{
            .sdl_window = sdl_window,
            .renderer = renderer,
        };
    }

    pub fn deinit(self: *const Self) void {
        sdl.SDL_DestroyRenderer(self.renderer);
    }

    pub fn renderLoop(self: *const Self, image_buffer: []const u8) !void {
        // SAFETY: will be filled with a valid width or return an error
        var width: c_int = undefined;
        // SAFETY: will be filled with a valid height or return an error
        var height: c_int = undefined;

        if (!sdl.SDL_GetWindowSize(
            self.sdl_window.window,
            &width,
            &height,
        )) {
            logSdlError("Could not get window size: %s\n", sdl.SDL_GetError());
            return error.SdlTextureCreationFailed;
        }

        const texture = sdl.SDL_CreateTexture(
            @ptrCast(self.renderer),
            sdl.SDL_PIXELFORMAT_RGB24,
            sdl.SDL_TEXTUREACCESS_STATIC,
            width,
            height,
        ) orelse {
            logSdlError("Could not create texture: %s\n", sdl.SDL_GetError());
            return error.SdlTextureCreationFailed;
        };

        _ = sdl.SDL_UpdateTexture(
            texture,
            null,
            @ptrCast(image_buffer),
            width * 3,
        );

        var is_running = true;

        while (is_running) {
            // SAFETY: will only be read after being filled with a valid event
            var event: sdl.SDL_Event = undefined;

            // handle all queued events
            while (sdl.SDL_PollEvent(&event)) {
                switch (event.type) {
                    sdl.SDL_EVENT_QUIT => is_running = false,
                    sdl.SDL_EVENT_KEY_DOWN => {
                        if (event.key.scancode == sdl.SDL_SCANCODE_ESCAPE) {
                            is_running = false;
                        }

                        if (event.key.key == sdl.SDLK_S) {
                            self.takeScreenshot();
                        }
                    },
                    else => {},
                }
            }

            // TODO update state

            // draw the current frame
            _ = sdl.SDL_SetRenderDrawColorFloat(self.renderer, 0.0, 0.0, 0.0, 1.0);
            _ = sdl.SDL_RenderClear(self.renderer);
            _ = sdl.SDL_RenderTexture(self.renderer, texture, null, null);
            _ = sdl.SDL_RenderPresent(self.renderer);
        }
    }

    fn takeScreenshot(self: *const Self) void {
        const screenshot = sdl.SDL_RenderReadPixels(
            self.renderer,
            null,
        );

        if (screenshot == null) {
            logSdlError(
                "Could not create screenshot: %s\n",
                sdl.SDL_GetError(),
            );
            return;
        }

        if (!sdl.SDL_SaveBMP(screenshot, "screenshot.bmp")) {
            logSdlError(
                "Could not save screenshot: %s\n",
                sdl.SDL_GetError(),
            );
        }

        sdl.SDL_DestroySurface(screenshot);
    }
};

pub const VulkanFunctionPointers = struct {
    vkGetInstanceProcAddr: std.meta.Child(vk.PFN_vkGetInstanceProcAddr),
    vkCreateInstance: std.meta.Child(vk.PFN_vkCreateInstance),
    vkDestroyInstance: std.meta.Child(vk.PFN_vkDestroyInstance),
};

pub const VulkanInstance = struct {
    const Self = @This();

    allocator_callbacks: ?vk.VkAllocationCallbacks,
    vk_functions: VulkanFunctionPointers,
    VkInstanceCreateInfo: vk.VkInstanceCreateInfo,
    instance: std.meta.Child(vk.VkInstance),

    pub fn init() !Self {
        // SAFETY: will be filled with a valid extension count or return an error
        var extensions_count: u32 = undefined;

        const extensions = sdl.SDL_Vulkan_GetInstanceExtensions(&extensions_count) orelse {
            logSdlError(
                "Retrieving Vulkan extensions failed: %s\n",
                sdl.SDL_GetError(),
            );
            return ApplicationError.SdlVulkanExtensionsNotFound;
        };

        for (0..extensions_count) |index| {
            std.debug.print("SDL vkExtension({}): {s}\n", .{ index, extensions[index] });
        }

        const allocator_callbacks: ?vk.VkAllocationCallbacks = null;

        const vk_get_instance_proc_addr = try lookupVkGetInstanceProcAddr();

        const vk_create_instance = try loadVkFunctionPointer(
            null,
            vk_get_instance_proc_addr,
            "vkCreateInstance",
        );

        const vk_instance_create_info = std.mem.zeroInit(vk.VkInstanceCreateInfo, .{
            .sType = vk.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
            .enabledExtensionCount = extensions_count,
            .ppEnabledExtensionNames = extensions,
        });

        // SAFETY: will be filled with a valid instance or return an error
        var instance: vk.VkInstance = undefined;

        _ = vk_create_instance(
            &vk_instance_create_info,
            @ptrCast(&allocator_callbacks),
            &instance,
        );

        if (instance == null) {
            logSdlError(
                "%s\n",
                "Could not create Vulkan instance!",
            );
            return ApplicationError.VulkanInstanceCreationFailed;
        }

        const vk_destroy_instance = try loadVkFunctionPointer(
            instance,
            vk_get_instance_proc_addr,
            "vkDestroyInstance",
        );

        return .{
            .allocator_callbacks = allocator_callbacks,
            .vk_functions = .{
                .vkGetInstanceProcAddr = vk_get_instance_proc_addr,
                .vkCreateInstance = vk_create_instance,
                .vkDestroyInstance = vk_destroy_instance,
            },
            .VkInstanceCreateInfo = vk_instance_create_info,
            .instance = instance.?,
        };
    }

    pub fn deinit(self: *const Self) void {
        self.vk_functions.vkDestroyInstance(
            self.instance,
            @ptrCast(&self.allocator_callbacks),
        );
    }

    /// Get type of the vulkan function pointer within an option.
    fn VkPfnPointerType(comptime name: []const u8) type {
        return std.meta.Child(@field(vk, "PFN_" ++ name));
    }

    /// Load vulkan function pointer and unpack it from the option type.
    fn lookupVkGetInstanceProcAddr() !VkPfnPointerType("vkGetInstanceProcAddr") {
        const vk_get_instance_proc_addr = sdl.SDL_Vulkan_GetVkGetInstanceProcAddr();

        if (vk_get_instance_proc_addr == null) {
            logSdlError(
                "Retrieving pointer to vkGetInstanceProcAddr failed: %s\n",
                sdl.SDL_GetError(),
            );

            return ApplicationError.VulkanLoadFunctionPointerFailed;
        }

        return @as(
            @field(vk, "PFN_vkGetInstanceProcAddr"),
            @ptrCast(vk_get_instance_proc_addr),
        ).?;
    }

    fn loadVkFunctionPointer(
        instance: vk.VkInstance,
        vk_get_instance_proc_addr: VkPfnPointerType("vkGetInstanceProcAddr"),
        comptime name: []const u8,
    ) !VkPfnPointerType(name) {
        const pfn_pointer: @field(vk, "PFN_" ++ name) = @ptrCast(
            vk_get_instance_proc_addr(
                instance,
                @ptrCast(name),
            ),
        );

        if (pfn_pointer == null) {
            logSdlError(
                "%s\n",
                "Retrieving pointer to '" ++ name ++ "' failed",
            );

            return ApplicationError.VulkanLoadFunctionPointerFailed;
        }

        return pfn_pointer.?;
    }
};

pub const VulkanSurface = struct {
    const Self = @This();

    vulkan_instance: *const VulkanInstance,
    surface: std.meta.Child(vk.VkSurfaceKHR),

    pub fn init(sdl_window: *const SdlWindow, vulkan_instance: *const VulkanInstance) !Self {
        // SAFETY: will be filled with a surface or return an error
        var surface: vk.VkSurfaceKHR = undefined;

        _ = sdl.SDL_Vulkan_CreateSurface(
            sdl_window.window,
            @ptrCast(vulkan_instance.*.instance),
            @ptrCast(&vulkan_instance.allocator_callbacks),
            &surface,
        );

        if (surface == null) {
            logSdlError("Could not create surface: %s\n", sdl.SDL_GetError());
            return ApplicationError.SdlSurfaceCreationFailed;
        }

        return .{
            .vulkan_instance = vulkan_instance,
            .surface = surface.?,
        };
    }

    pub fn deinit(self: *const Self) void {
        sdl.SDL_Vulkan_DestroySurface(
            @ptrCast(self.vulkan_instance.*.instance),
            @ptrCast(self.surface),
            @ptrCast(&self.vulkan_instance.allocator_callbacks),
        );
    }
};

fn logSdlError(fmt: [*c]const u8, err: [*c]const u8) void {
    sdl.SDL_LogError(
        sdl.SDL_LOG_CATEGORY_APPLICATION,
        fmt,
        err,
    );
}
