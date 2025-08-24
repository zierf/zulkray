const std = @import("std");
const builtin = @import("builtin");

const sdl = @cImport({
    @cInclude("SDL3/SDL.h");
    @cInclude("SDL3/SDL_vulkan.h");
});

const vk = @cImport({
    @cDefine("VK_NO_PROTOTYPES", {});
    @cInclude("vulkan/vulkan.h");
});

const Alignment = std.mem.Alignment;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

pub const RenderError = error{
    SdlInitializationFailed,
    SdlRendererNotFound,
    SdlSurfaceCreationFailed,
    SdlTextureCreationFailed,
    SdlVulkanExtensionsNotFound,
    SdlWindowCreationFailed,
    VulkanEnumerateExtensionsFailed,
    VulkanEnumerateLayersFailed,
    VulkanInstanceCreationFailed,
    VulkanLoadFunctionPointerFailed,
    VulkanLoadExtensionsFailed,
    VulkanLoadLayersFailed,
};

pub fn opaqueToPointer(comptime T: type, ptr: ?*anyopaque) T {
    return @ptrCast(@alignCast(ptr));
}

pub fn cleanupSentinelStringSlice(allocator: Allocator, strings: [][*:0]const u8) void {
    for (strings) |cstr| {
        const len = std.mem.len(cstr);
        // don't forget to free the sentinel too
        allocator.free(cstr[0..(len + 1)]);
    }

    allocator.free(strings);
}

pub const SdlWindow = struct {
    const Self = @This();

    window: *sdl.SDL_Window,

    pub fn init(
        window_title: [*:0]const u8,
        width: usize,
        height: usize,
    ) !Self {
        if (!sdl.SDL_Init(sdl.SDL_INIT_VIDEO)) {
            logSdlError(
                "Could not initialize SDL: %s\n",
                sdl.SDL_GetError(),
            );
            return RenderError.SdlInitializationFailed;
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
            return RenderError.SdlWindowCreationFailed;
        };

        return .{
            .window = sdl_window,
        };
    }

    pub fn deinit(self: *const Self) void {
        sdl.SDL_DestroyWindow(self.window);
        sdl.SDL_Quit();
    }

    pub fn getRequiredExtensionNames() ![]const [*:0]const u8 {
        // SAFETY: will be filled with a valid extension count or return an error
        var extensions_count: u32 = undefined;

        // "You should not free the returned array; it is owned by SDL."
        // see https://wiki.libsdl.org/SDL3/SDL_Vulkan_GetInstanceExtensions
        const extensions = sdl.SDL_Vulkan_GetInstanceExtensions(&extensions_count) orelse {
            logSdlError(
                "Retrieving Vulkan extensions failed: %s\n",
                sdl.SDL_GetError(),
            );
            return RenderError.SdlVulkanExtensionsNotFound;
        };

        const extension_slice: []const [*:0]const u8 = @ptrCast(extensions[0..extensions_count]);

        return extension_slice;
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
            return RenderError.SdlRendererNotFound;
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

        main_loop: while (true) {
            // handle all queued events
            while (pollEvent()) |event| {
                switch (event.type) {
                    sdl.SDL_EVENT_QUIT => break :main_loop,
                    sdl.SDL_EVENT_KEY_DOWN => {
                        if (event.key.scancode == sdl.SDL_SCANCODE_ESCAPE) {
                            break :main_loop;
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

    fn pollEvent() ?sdl.SDL_Event {
        // SAFETY: will only be read after being filled with a valid event
        var event: sdl.SDL_Event = undefined;

        if (sdl.SDL_PollEvent(&event)) {
            return event;
        }

        return null;
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

/// Auto loader for vulkan function pointers.
pub const VkFnDispatcher = struct {
    const Self = @This();
    const proc_addr_name = "vkGetInstanceProcAddr";

    vkGetInstanceProcAddr: std.meta.Child(vk.PFN_vkGetInstanceProcAddr),
    vkEnumerateInstanceExtensionProperties: std.meta.Child(vk.PFN_vkEnumerateInstanceExtensionProperties),
    vkEnumerateInstanceLayerProperties: std.meta.Child(vk.PFN_vkEnumerateInstanceLayerProperties),

    vkCreateInstance: std.meta.Child(vk.PFN_vkCreateInstance),
    vkDestroyInstance: std.meta.Child(vk.PFN_vkDestroyInstance),

    pub fn init(
        instance: vk.VkInstance,
        vk_get_instance_proc_addr: VkPfnPointerType(proc_addr_name),
    ) !Self {
        // https://registry.khronos.org/vulkan/specs/latest/man/html/vkGetInstanceProcAddr.html
        const global_commands = [_][]const u8{
            proc_addr_name, // Vulkan 1.2
            "vkEnumerateInstanceVersion",
            "vkEnumerateInstanceExtensionProperties",
            "vkEnumerateInstanceLayerProperties",
            "vkCreateInstance",
        };

        // SAFETY: all fields will be set, otherwise return an error
        var self: Self = undefined;
        // @memset(std.mem.asBytes(&self), 0x00);

        std.debug.print("Load Vulkan Function Pointers:\n", .{});

        inline for (std.meta.fields(Self)) |field| {
            const fn_name = field.name;

            var instance_pointer = instance;

            for (global_commands) |global_command| {
                if (std.mem.eql(u8, global_command, fn_name)) {
                    instance_pointer = null;
                    std.debug.print("Vulkan FnPtr: {s} (global)\n", .{fn_name});
                    break;
                }
            } else {
                std.debug.print("Vulkan FnPtr: {s} (instanced)\n", .{fn_name});
            }

            @field(self, fn_name) = try Self.loadVkFunctionPointer(
                instance_pointer,
                vk_get_instance_proc_addr,
                fn_name,
            );
        }

        std.debug.print("\n", .{});

        return self;
    }

    /// Get type of the vulkan function pointer within an option.
    pub fn VkPfnPointerType(comptime name: []const u8) type {
        return std.meta.Child(@field(vk, "PFN_" ++ name));
    }

    /// Loookup vulkan function pointer loader and unpack it from the option type.
    pub fn lookupVkGetInstanceProcAddr() !VkPfnPointerType(proc_addr_name) {
        const vk_get_instance_proc_addr = sdl.SDL_Vulkan_GetVkGetInstanceProcAddr();

        if (vk_get_instance_proc_addr == null) {
            logSdlError(
                "Retrieving pointer to " ++ proc_addr_name ++ " failed: %s\n",
                sdl.SDL_GetError(),
            );

            return RenderError.VulkanLoadFunctionPointerFailed;
        }

        // The actual type of the returned function pointer is PFN_vkGetInstanceProcAddr,
        // but that isn't available because the Vulkan headers are not included here.
        // see https://wiki.libsdl.org/SDL3/SDL_Vulkan_GetVkGetInstanceProcAddr
        return @as(
            @field(vk, "PFN_" ++ proc_addr_name),
            @ptrCast(vk_get_instance_proc_addr),
        ).?;
    }

    /// Load vulkan function pointer and unpack it from the option type.
    pub fn loadVkFunctionPointer(
        instance: vk.VkInstance,
        vk_get_instance_proc_addr: VkPfnPointerType(proc_addr_name),
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

            return RenderError.VulkanLoadFunctionPointerFailed;
        }

        return pfn_pointer.?;
    }
};

/// Use allocations with an additional header to keep track of initial size and alignment.
/// see https://www.reddit.com/r/Zig/comments/1mbn4q1/using_zig_allocator_for_c_libraries_alignment/
const ManagedAllocation = struct {
    header: *AllocationHeader,
    full_slice: []u8,
    consumer_slice: []u8,

    pub const AllocationHeader = struct {
        size: usize,
        alignment: usize,
    };

    pub fn calculateManagedSize(size: usize) usize {
        return @sizeOf(AllocationHeader) + size;
    }

    pub fn fromConsumerPointer(allocation: ?*anyopaque) @This() {
        const allocation_ptr = @intFromPtr(allocation);

        const header_address = allocation_ptr - @sizeOf(AllocationHeader);
        const header_start: [*]u8 = @ptrFromInt(header_address);
        const header_ptr: *AllocationHeader = @alignCast(@ptrCast(header_start));

        const full_slice = header_start[0..(header_ptr.*.size + @sizeOf(AllocationHeader))];
        const consumer_slice = @as([*]u8, @ptrFromInt(allocation_ptr))[0..header_ptr.*.size];

        return .{
            .header = header_ptr,
            .full_slice = full_slice,
            .consumer_slice = consumer_slice,
        };
    }

    pub fn alloc(allocator: Allocator, size: usize, alignment: usize) ?@This() {
        const total_size = calculateManagedSize(size);

        const allocation = allocator.rawAlloc(
            total_size,
            Alignment.fromByteUnits(alignment),
            @returnAddress(),
        ) orelse {
            return null;
        };

        const header_ptr: *AllocationHeader = @alignCast(@ptrCast(allocation));
        header_ptr.* = .{
            .size = size,
            .alignment = alignment,
        };

        const full_slice = allocation[0..total_size];
        const consumer_slice = full_slice[@sizeOf(AllocationHeader)..full_slice.len];

        return .{
            .header = header_ptr,
            .full_slice = full_slice,
            .consumer_slice = consumer_slice,
        };
    }

    pub fn free(self: *const @This(), allocator: Allocator) void {
        allocator.rawFree(
            self.full_slice,
            Alignment.fromByteUnits(self.header.*.alignment),
            @returnAddress(),
        );
    }
};

const VulkanAllocator = struct {
    const Self = @This();

    const max_alignment = @alignOf(std.c.max_align_t);

    allocator: Allocator,
    allocation_callbacks_ptr: ?*vk.VkAllocationCallbacks,
    tracker: AllocationTracker,

    pub const AllocationTracker = struct {
        bytes_allocated: usize,
        bytes_reallocated: usize,
        bytes_freed: usize,
        count_allocated: usize,
        count_reallocated: usize,
        count_freed: usize,
    };

    pub fn create(allocator: Allocator) !*Self {
        const self = try allocator.create(Self);

        const vk_allocation_callbacks: ?*vk.VkAllocationCallbacks = blk: switch (builtin.mode) {
            .Debug, .ReleaseSafe => {
                const callbacks: *vk.VkAllocationCallbacks = try allocator.create(vk.VkAllocationCallbacks);
                callbacks.* = .{
                    .pUserData = self,
                    .pfnAllocation = &pfnAllocation,
                    .pfnReallocation = &pfnReallocation,
                    .pfnFree = &pfnFree,
                    .pfnInternalAllocation = &pfnInternalAllocation,
                    .pfnInternalFree = &pfnInternalFree,
                };

                break :blk callbacks;
            },
            else => {
                break :blk null;
            },
        };

        self.* = .{
            .allocator = allocator,
            .allocation_callbacks_ptr = vk_allocation_callbacks,
            .tracker = std.mem.zeroes(AllocationTracker),
        };

        return self;
    }

    pub fn destroy(self: *const Self) void {
        switch (builtin.mode) {
            .Debug, .ReleaseSafe => self.printStatistics(),
            else => {},
        }

        if (self.allocation_callbacks_ptr != null) {
            self.allocator.destroy(self.allocation_callbacks_ptr.?);
        }

        self.allocator.destroy(self);
    }

    pub fn printStatistics(self: *const Self) void {
        // format in B|KiB|MiB|GiB|TiB (std.fmt.fmtIntSizeBin) / B|kB|MB|GB|TB (std.fmt.fmtIntSizeDec)
        std.debug.print(
            \\Allocations:   {: >10.3} ({})
            \\Reallocations: {: >10.3} ({})
            \\Total:         {: >10.3} ({})
            \\Freed:         {: >10.3} ({})
            \\
        , .{
            std.fmt.fmtIntSizeBin(self.tracker.bytes_allocated),
            self.tracker.count_allocated,
            std.fmt.fmtIntSizeBin(self.tracker.bytes_reallocated),
            self.tracker.count_reallocated,
            std.fmt.fmtIntSizeBin(self.tracker.bytes_allocated + self.tracker.bytes_reallocated),
            self.tracker.count_allocated + self.tracker.count_reallocated,
            std.fmt.fmtIntSizeBin(self.tracker.bytes_freed),
            self.tracker.count_freed,
        });
    }

    /// see https://registry.khronos.org/vulkan/specs/latest/man/html/PFN_vkAllocationFunction.html
    fn pfnAllocation(
        pUserData: ?*anyopaque,
        size: usize,
        alignment: usize,
        allocationScope: vk.VkSystemAllocationScope,
    ) callconv(.c) ?*anyopaque {
        _ = allocationScope;

        if (pUserData == null or size == 0) {
            // unable to allocate memory without a context including an allocator
            // n
            return null;
        }

        const self = opaqueToPointer(*Self, pUserData);

        const magaged_alloc = ManagedAllocation.alloc(
            self.allocator,
            size,
            alignment,
        ) orelse {
            // "If pfnAllocation is unable to allocate the requested memory, it must return NULL."
            return null;
        };

        self.tracker.bytes_allocated += size;
        self.tracker.count_allocated += 1;

        return magaged_alloc.consumer_slice.ptr;
    }

    /// see https://registry.khronos.org/vulkan/specs/latest/man/html/PFN_vkReallocationFunction.html
    fn pfnReallocation(
        pUserData: ?*anyopaque,
        pOriginal: ?*anyopaque,
        size: usize,
        alignment: usize,
        allocationScope: vk.VkSystemAllocationScope,
    ) callconv(.c) ?*anyopaque {
        // no clear statement as to whether new allocation or free has priority
        // just checking in order of specification description
        if (pOriginal == null) {
            // completely new allocation
            return pfnAllocation(pUserData, size, alignment, allocationScope);
        }

        if (size == 0) {
            // free allocation
            pfnFree(pUserData, pOriginal);
            // the specification states it must behave like free, but the return values ​​are different
            // just assume that NULL is returned here, no allocation to point from here
            return null;
        }

        if (pUserData == null) {
            // unable to allocate memory without a context including an allocator
            return null;
        }

        // create new allocation
        const self = opaqueToPointer(*Self, pUserData);

        const new_alloc = ManagedAllocation.alloc(self.allocator, size, alignment) orelse {
            // "If this function fails and pOriginal is non-NULL the application must not free the old allocation."
            //
            // "pfnReallocation must follow the same rules for return values as PFN_vkAllocationFunction."
            //  -> "If pfnAllocation is unable to allocate the requested memory, it must return NULL."
            return null;
        };

        const old_alloc = ManagedAllocation.fromConsumerPointer(pOriginal);

        // copy as much old memory as possible to the new allocation
        const bytes_to_copy: usize = @min(old_alloc.consumer_slice.len, new_alloc.consumer_slice.len);

        @memcpy(
            new_alloc.consumer_slice[0..bytes_to_copy],
            old_alloc.consumer_slice[0..bytes_to_copy],
        );

        // free old memory
        const length_freed = old_alloc.consumer_slice.len;
        old_alloc.free(self.allocator);

        self.tracker.bytes_reallocated += size;
        self.tracker.bytes_freed += length_freed;
        self.tracker.count_reallocated += 1;
        self.tracker.count_freed += 1;

        return new_alloc.consumer_slice.ptr;
    }

    /// see https://registry.khronos.org/vulkan/specs/latest/man/html/PFN_vkFreeFunction.html
    fn pfnFree(
        pUserData: ?*anyopaque,
        pMemory: ?*anyopaque,
    ) callconv(.c) void {
        if (pMemory == null) {
            return;
        }

        const self = opaqueToPointer(*Self, pUserData);

        const managed_alloc = ManagedAllocation.fromConsumerPointer(pMemory);

        const length_freed = managed_alloc.consumer_slice.len;
        managed_alloc.free(self.allocator);

        self.tracker.bytes_freed += length_freed;
        self.tracker.count_freed += 1;
    }

    /// see https://registry.khronos.org/vulkan/specs/latest/man/html/PFN_vkInternalAllocationNotification.html
    fn pfnInternalAllocation(
        pUserData: ?*anyopaque,
        size: usize,
        allocationType: vk.VkInternalAllocationType,
        allocationScope: vk.VkSystemAllocationScope,
    ) callconv(.c) void {
        _ = pUserData;

        std.debug.print("Internal Allocation of {} Bytes (Type {}) in Scope {}\n", .{ size, allocationType, allocationScope });
    }

    /// see https://registry.khronos.org/vulkan/specs/latest/man/html/PFN_vkInternalFreeNotification.html
    fn pfnInternalFree(
        pUserData: ?*anyopaque,
        size: usize,
        allocationType: vk.VkInternalAllocationType,
        allocationScope: vk.VkSystemAllocationScope,
    ) callconv(.c) void {
        _ = pUserData;

        std.debug.print("Internal Free of {} Bytes (Type {}) in Scope {}\n", .{ size, allocationType, allocationScope });
    }
};

pub const VulkanInstance = struct {
    const Self = @This();

    allocator: Allocator,
    vulkan_allocator: *VulkanAllocator,
    dispatcher: VkFnDispatcher,
    layers: [][*:0]const u8,
    extensions: [][*:0]const u8,
    vk_instance_create_info: vk.VkInstanceCreateInfo,
    instance: std.meta.Child(vk.VkInstance),

    pub fn init(allocator: Allocator) !Self {
        const layers = try Self.loadLayers(allocator);
        errdefer cleanupSentinelStringSlice(allocator, layers);

        const extensions = try Self.loadExtensions(allocator);
        errdefer cleanupSentinelStringSlice(allocator, extensions);

        const vk_instance_create_info = std.mem.zeroInit(vk.VkInstanceCreateInfo, .{
            .sType = vk.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
            .enabledLayerCount = @as(u32, @intCast(layers.len)),
            .ppEnabledLayerNames = layers.ptr,
            .enabledExtensionCount = @as(u32, @intCast(extensions.len)),
            .ppEnabledExtensionNames = extensions.ptr,
        });

        const vulkan_allocator = try VulkanAllocator.create(allocator);
        errdefer vulkan_allocator.destroy();

        const vk_get_instance_proc_addr = try VkFnDispatcher.lookupVkGetInstanceProcAddr();

        const vk_create_instance = try VkFnDispatcher.loadVkFunctionPointer(
            null,
            vk_get_instance_proc_addr,
            "vkCreateInstance",
        );

        // SAFETY: will be filled with a valid instance or return an error
        var instance: vk.VkInstance = undefined;

        const instance_creation_result = vk_create_instance(
            &vk_instance_create_info,
            vulkan_allocator.allocation_callbacks_ptr,
            &instance,
        );

        if (instance_creation_result != vk.VK_SUCCESS) {
            logSdlError(
                "%s\n",
                "Could not create Vulkan instance!",
            );
            return RenderError.VulkanInstanceCreationFailed;
        }

        const dispatcher = VkFnDispatcher.init(
            instance,
            vk_get_instance_proc_addr,
        ) catch {
            const vk_destroy_instance = try VkFnDispatcher.loadVkFunctionPointer(
                instance,
                vk_get_instance_proc_addr,
                "vkDestroyInstance",
            );

            vk_destroy_instance(
                instance,
                vulkan_allocator.allocation_callbacks_ptr,
            );

            return RenderError.VulkanLoadFunctionPointerFailed;
        };

        return .{
            .allocator = allocator,
            .vulkan_allocator = vulkan_allocator,
            .dispatcher = dispatcher,
            .layers = layers,
            .extensions = extensions,
            .vk_instance_create_info = vk_instance_create_info,
            .instance = instance.?,
        };
    }

    pub fn deinit(self: *const Self) void {
        self.dispatcher.vkDestroyInstance(
            self.instance,
            self.vulkan_allocator.allocation_callbacks_ptr,
        );

        self.vulkan_allocator.destroy();

        cleanupSentinelStringSlice(self.allocator, self.extensions);
        cleanupSentinelStringSlice(self.allocator, self.layers);
    }

    pub fn getAvailableLayers(allocator: Allocator) ![]const vk.VkLayerProperties {
        const vk_get_instance_proc_addr = try VkFnDispatcher.lookupVkGetInstanceProcAddr();

        const enumerate_layers = try VkFnDispatcher.loadVkFunctionPointer(
            null,
            vk_get_instance_proc_addr,
            "vkEnumerateInstanceLayerProperties",
        );

        // SAFETY: will be filled with a valid layer count or return an error
        var layer_count: u32 = undefined;

        if (enumerate_layers(&layer_count, null) != vk.VK_SUCCESS) {
            return RenderError.VulkanEnumerateLayersFailed;
        }

        const available_layers: []vk.VkLayerProperties = try allocator.alloc(
            vk.VkLayerProperties,
            layer_count,
        );
        errdefer allocator.free(available_layers);

        if (enumerate_layers(&layer_count, available_layers.ptr) != vk.VK_SUCCESS) {
            return RenderError.VulkanEnumerateLayersFailed;
        }

        return available_layers;
    }

    pub fn getAvailableExtensions(allocator: Allocator) ![]const vk.VkExtensionProperties {
        const vk_get_instance_proc_addr = try VkFnDispatcher.lookupVkGetInstanceProcAddr();

        const enumerate_extensions = try VkFnDispatcher.loadVkFunctionPointer(
            null,
            vk_get_instance_proc_addr,
            "vkEnumerateInstanceExtensionProperties",
        );

        // SAFETY: will be filled with a valid extension count or return an error
        var extension_count: u32 = undefined;

        if (enumerate_extensions(null, &extension_count, null) != vk.VK_SUCCESS) {
            return RenderError.VulkanEnumerateExtensionsFailed;
        }

        const available_layers: []vk.VkExtensionProperties = try allocator.alloc(
            vk.VkExtensionProperties,
            extension_count,
        );
        errdefer allocator.free(available_layers);

        if (enumerate_extensions(null, &extension_count, available_layers.ptr) != vk.VK_SUCCESS) {
            return RenderError.VulkanEnumerateExtensionsFailed;
        }

        return available_layers;
    }

    fn checkUnsupportedLayers(allocator: Allocator, layers: []const [*:0]const u8) !ArrayList([*:0]const u8) {
        const available_layers = try getAvailableLayers(allocator);
        defer allocator.free(available_layers);

        var unsupported = try ArrayList([*:0]const u8).initCapacity(allocator, 0);
        errdefer unsupported.deinit();

        for (layers) |*requested_layer| {
            const found_layer =
                found: for (available_layers) |*available_layer| {
                    const layer_name: [*:0]const u8 = @ptrCast(&available_layer.*.layerName);

                    if (std.mem.orderZ(u8, requested_layer.*, layer_name) == .eq) {
                        break :found true;
                    }
                } else false;

            if (!found_layer) {
                try unsupported.append(requested_layer.*);
            }
        }

        return unsupported;
    }

    fn checkUnsupportedExtensions(allocator: Allocator, extensions: []const [*:0]const u8) !ArrayList([*:0]const u8) {
        const available_extensions = try getAvailableExtensions(allocator);
        defer allocator.free(available_extensions);

        var unsupported = try ArrayList([*:0]const u8).initCapacity(allocator, 0);
        errdefer unsupported.deinit();

        for (extensions) |*requested_extension| {
            const found_extension =
                found: for (available_extensions) |*available_extension| {
                    const extension_name: [*:0]const u8 = @ptrCast(&available_extension.*.extensionName);

                    if (std.mem.orderZ(u8, requested_extension.*, extension_name) == .eq) {
                        break :found true;
                    }
                } else false;

            if (!found_extension) {
                try unsupported.append(requested_extension.*);
            }
        }

        return unsupported;
    }

    fn loadLayers(allocator: Allocator) ![][*:0]const u8 {
        const layers = if (builtin.mode == .Debug) [_][]const u8{
            // prepend list for debug builds
            "VK_LAYER_KHRONOS_validation",
        } else [_][]const u8{
            // prepend list for release builds
        };

        std.debug.print("Create Layer List for Application:\n", .{});

        // reserve enough space for list of layers
        var application_layers: [][*:0]const u8 = try allocator.alloc(
            [*:0]const u8,
            layers.len,
        );
        errdefer cleanupSentinelStringSlice(allocator, application_layers);

        for (layers, 0..) |layer_name, index| {
            application_layers[index] = (try allocator.dupeZ(u8, layer_name)).ptr;
        }

        for (application_layers, 0..) |layer_name, index| {
            std.debug.print("vkLayer({}): {s}\n", .{ index, layer_name });
        }

        std.debug.print("\n", .{});

        const unsupported_layers = try checkUnsupportedLayers(allocator, application_layers);
        defer unsupported_layers.deinit();

        if (unsupported_layers.items.len > 0) {
            for (unsupported_layers.items) |*unsupported_layer| {
                const unsupported_name = std.mem.span(unsupported_layer.*);
                logSdlError("Could not load layer: %s\n", unsupported_name);
            }
            return RenderError.VulkanLoadLayersFailed;
        }

        return application_layers;
    }

    fn loadExtensions(allocator: Allocator) ![][*:0]const u8 {
        std.debug.print("Load SDL required extensions:\n", .{});

        const sdl_extensions = try SdlWindow.getRequiredExtensionNames();

        for (sdl_extensions, 0..) |extension, index| {
            std.debug.print("vkExtension({}): {s} (SDL required)\n", .{ index, extension });
        }
        std.debug.print("\n", .{});

        const extensions_prepend = if (builtin.mode == .Debug) [_][]const u8{
            // prepend list for debug builds
        } else [_][]const u8{
            // prepend list for release builds
        };

        std.debug.print("Create Extensions List for Application:\n", .{});

        // reserve enough space for own and SDL required extensions
        var application_extensions: [][*:0]const u8 = try allocator.alloc(
            [*:0]const u8,
            sdl_extensions.len + extensions_prepend.len,
        );
        errdefer cleanupSentinelStringSlice(allocator, application_extensions);

        for (extensions_prepend, 0..) |extension_name, index| {
            application_extensions[index] = (try allocator.dupeZ(u8, extension_name)).ptr;
        }

        for (sdl_extensions, 0..) |extension_name, index| {
            const str_len = std.mem.len(extension_name);
            application_extensions[index + extensions_prepend.len] = (try allocator.dupeZ(
                u8,
                extension_name[0..str_len],
            )).ptr;
        }

        for (application_extensions, 0..) |extension_name, index| {
            std.debug.print("vkExtension({}): {s}\n", .{ index, extension_name });
        }

        std.debug.print("\n", .{});

        const unsupported_extensions = try checkUnsupportedExtensions(allocator, application_extensions);
        defer unsupported_extensions.deinit();

        if (unsupported_extensions.items.len > 0) {
            for (unsupported_extensions.items) |*unsupported_extension| {
                const unsupported_name = std.mem.span(unsupported_extension.*);
                logSdlError("Could not load extension: %s\n", unsupported_name);
            }
            return RenderError.VulkanLoadExtensionsFailed;
        }

        return application_extensions;
    }
};

pub const VulkanSurface = struct {
    const Self = @This();

    vulkan_instance: *const VulkanInstance,
    surface: std.meta.Child(vk.VkSurfaceKHR),

    pub fn init(sdl_window: *const SdlWindow, vulkan_instance: *const VulkanInstance) !Self {
        // SAFETY: will be filled with a surface or return an error
        var surface: vk.VkSurfaceKHR = undefined;

        const surface_creation_success = sdl.SDL_Vulkan_CreateSurface(
            sdl_window.window,
            @ptrCast(vulkan_instance.*.instance),
            @ptrCast(vulkan_instance.vulkan_allocator.allocation_callbacks_ptr),
            &surface,
        );

        if (!surface_creation_success) {
            logSdlError("Could not create surface: %s\n", sdl.SDL_GetError());
            return RenderError.SdlSurfaceCreationFailed;
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
            @ptrCast(self.vulkan_instance.vulkan_allocator.allocation_callbacks_ptr),
        );
    }
};

fn logSdlError(fmt: [*:0]const u8, err: [*:0]const u8) void {
    sdl.SDL_LogError(
        sdl.SDL_LOG_CATEGORY_APPLICATION,
        fmt,
        err,
    );
}
