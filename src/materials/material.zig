const std = @import("std");

const Allocator = std.mem.Allocator;
const StringHashMap = std.StringHashMap;

const vector = @import("../vector.zig");
const Ray = @import("../Ray.zig");
const Random = @import("../Random.zig");

pub const Dielectric = @import("Dielectric.zig");
pub const Lambertian = @import("Lambertian.zig");
pub const Metal = @import("Metal.zig");

const Vec3f = vector.Vec3f;

pub const Material = union(enum) {
    Dielectric: Dielectric,
    Lambertian: Lambertian,
    Metal: Metal,

    const Self = @This();

    pub fn scatter(
        self: *const Self,
        rand: *Random,
        ray: *const Ray,
        hit_record: *const Ray.HitRecord,
    ) !?Ray.ScatterRay {
        return switch (self.*) {
            inline else => |mat| try mat.scatter(rand, ray, hit_record),
        };
    }
};

pub const MaterialMap = struct {
    allocator: Allocator,
    hash_map: StringHashMap(Material),

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return .{
            .allocator = allocator,
            .hash_map = StringHashMap(Material).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        // https://www.openmymind.net/Zigs-HashMap-Part-2/
        var it = self.hash_map.iterator();
        while (it.next()) |kv| {
            self.allocator.free(kv.key_ptr.*);
            // self.allocator.destroy(kv.value_ptr.*);
        }
        self.hash_map.deinit();
    }

    pub fn add(self: *Self, key: []const u8, material: Material) !([]const u8) {
        const entry = try self.hash_map.getOrPut(key);

        if (!entry.found_existing) {
            // own the string for the lifetime of the HashMap
            // using .put(…) with a dupe will copy the string slice and leak after resizing
            // see https://github.com/ziglang/zig/issues/7765#issuecomment-2053520260
            // see https://www.openmymind.net/GetOrPut-With-String-Keys/#stringKeys
            entry.key_ptr.* = try self.allocator.dupe(u8, key);
        }

        // overwrite exisiting material
        entry.value_ptr.* = material;

        return entry.key_ptr.*;
    }

    pub fn remove(self: *Self, key: []const u8) ?Material {
        if (self.hash_map.fetchRemove(key)) |kv| {
            self.allocator.free(kv.key);
            // self.allocator.destroy(kv.value);

            return kv.value;
        }

        return null;
    }

    pub fn getPtr(self: *const Self, key: []const u8) ?*Material {
        return self.hash_map.getPtr(key);
    }
};
