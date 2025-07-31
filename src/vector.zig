const std = @import("std");

const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectError = std.testing.expectError;

const epsilonNearZero = 1e-8;

pub const VecError = error{
    DivisionByZero,
    UnitVectorForZero,
};

pub fn Vector(comptime T: type, comptime dim: usize) type {
    // some useful compiler checks
    // (see https://github.com/ziglang/zig/issues/20663#issuecomment-2233775965)
    if (@typeInfo(T) != .float and @typeInfo(T) != .int) {
        @compileError("Vector not implemented for " ++ @typeName(T));
    }

    if (dim <= 1) {
        @compileError("Dimension must be greater than one!");
    }

    return struct {
        const Self = @This();

        const VecType = @Vector(dim, T);

        vector: VecType,

        pub fn init(members: anytype) Self {
            const new_vec: VecType = members;

            return .{
                .vector = new_vec,
            };
        }

        pub fn byteSize() usize {
            return @sizeOf(VecType);
        }

        pub fn elementType() type {
            return T;
        }

        pub fn typeName() []const u8 {
            return @typeName(@typeInfo(VecType).vector.child);
        }

        pub fn dimension() usize {
            return @typeInfo(VecType).vector.len;
        }

        /// Create a new vector with given dimension, using current values.
        ///
        /// New elements are appended with the fill value.
        ///
        /// `Vec2f.init(.{ 1, 2 }).changeDimension(4, 0)` will create a new vector with elements `{ 1, 2, 0, 0 }`.
        ///
        /// If the new dimension is smaller than the current one, elements are truncated.
        ///
        /// `Vec4f.init(.{ 1, 2, 3, 4 }).changeDimension(2, 0)` will create a new vector with elements `{ 1, 2 }`.
        pub fn changeDimension(self: *const Self, comptime new_dimension: usize, fill: T) Vector(
            T,
            new_dimension,
        ) {
            if (new_dimension == dim) {
                return Self.init(self.vector);
            }

            const NewVecType = Vector(T, new_dimension);

            var new_values = [1]T{fill} ** new_dimension;

            for (&new_values, 0..) |*val, index| {
                if (index < dim) {
                    val.* = self.vector[index];
                }
            }

            return NewVecType.init(new_values);
        }

        pub fn zero() Self {
            return Self.init([1]T{0} ** dim);
        }

        pub fn one() Self {
            return Self.init([1]T{1} ** dim);
        }

        pub fn splat(scalar: T) Self {
            const new_vec: VecType = @splat(scalar);
            return Self.init(new_vec);
        }

        pub fn negate(self: *const Self) Self {
            return self.multiply(-1);
        }

        pub fn lengthSquared(self: *const Self) T {
            return @reduce(.Add, self.vector * self.vector);
        }

        pub fn length(self: *const Self) T {
            return @sqrt(self.lengthSquared());
        }

        pub fn unit(self: *const Self) !Self {
            const len = self.length();

            if (isFloatEqual(T, 0, len)) {
                return VecError.UnitVectorForZero;
            }

            return self.divide(len) catch unreachable;
        }

        pub fn addVec(self: *const Self, other: Self) Self {
            return Self.init(self.vector + other.vector);
        }

        pub fn subtractVec(self: *const Self, other: Self) Self {
            return Self.init(self.vector - other.vector);
        }

        pub usingnamespace if (dim == 3) struct {
            /// 3D cross product:
            /// ```
            /// (a, b, c) x (d, e, f) = (b*f - c*e, c*d - a*f, a*e - b*d)
            /// ```
            pub fn cross(self: *const Self, other: Self) Self {
                return Self.init(.{
                    self.y() * other.z() - self.z() * other.y(),
                    self.z() * other.x() - self.x() * other.z(),
                    self.x() * other.y() - self.y() * other.x(),
                });
            }
        } else if (dim == 2) struct {
            /// 2D cross product:
            /// ```
            /// (a, b) x (c, d) = a*d - b*c
            /// ```
            ///
            /// via 3D Z-Component:
            /// ```
            /// (a, b, 0) x (c, d, 0) = (0, 0, a*d - b*c)
            /// ```
            pub fn cross(self: *const Self, other: Self) T {
                return self.x() * other.y() - self.y() * other.x();
            }
        } else struct {};

        pub fn dot(self: *const Self, other: Self) T {
            return @reduce(.Add, self.vector * other.vector);
        }

        pub fn isPerpendicular(self: *const Self, other: Self) bool {
            return isFloatEqual(T, 0.0, self.dot(other));
        }

        pub fn isNearZero(self: *const Self) bool {
            const epsilon: VecType = @splat(std.math.floatEps(T));
            return @reduce(.And, @abs(self.vector) < epsilon);
        }

        pub fn angleRad(self: *const Self, other: Self) T {
            return std.math.acos(
                self.dot(other) / (self.length() * other.length()),
            );
        }

        pub fn angleDeg(self: *const Self, other: Self) T {
            return std.math.radiansToDegrees(self.angleRad(other));
        }

        pub fn add(self: *const Self, scalar: T) Self {
            const addend: Self = Self.splat(scalar);
            return self.addVec(addend);
        }

        pub fn subtract(self: *const Self, scalar: T) Self {
            const subtrahend: Self = Self.splat(scalar);
            return self.subtractVec(subtrahend);
        }

        pub fn multiply(self: *const Self, scalar: T) Self {
            const multiplier: Self = Self.splat(scalar);
            return Self.init(self.vector * multiplier.vector);
        }

        pub fn divide(self: *const Self, scalar: T) !Self {
            if (scalar == 0) {
                return VecError.DivisionByZero;
            }

            const divisor: Self = Self.splat(scalar);
            return Self.init(self.vector / divisor.vector);
        }

        // math vectors 2D/3D/4D
        pub usingnamespace if (dim >= 2 and dim <= 4) struct {
            pub fn x(self: *const Self) T {
                return self.vector[0];
            }
            pub fn y(self: *const Self) T {
                return self.vector[1];
            }
        } else struct {};

        // math vectors 3D
        pub usingnamespace if (dim >= 3) struct {
            pub fn z(self: *const Self) T {
                return self.vector[2];
            }
        } else struct {};

        // math vectors 4D
        pub usingnamespace if (dim >= 4) struct {
            pub fn w(self: *const Self) T {
                return self.vector[3];
            }
        } else struct {};

        // UV texture coordinates
        pub usingnamespace if (dim == 2) struct {
            pub fn u(self: *const Self) T {
                return self.vector[0];
            }

            pub fn v(self: *const Self) T {
                return self.vector[1];
            }
        } else struct {};

        // color RGB/RGBA
        pub usingnamespace if (dim >= 3 and dim <= 4) struct {
            pub fn r(self: *const Self) T {
                return self.vector[0];
            }

            pub fn g(self: *const Self) T {
                return self.vector[1];
            }

            pub fn b(self: *const Self) T {
                return self.vector[2];
            }

            pub fn rByte(self: *const Self) u8 {
                const byte: f32 = @min(1.0, self.r());
                return @intFromFloat(255.999 * byte);
            }

            pub fn gByte(self: *const Self) u8 {
                const byte: f32 = @min(1.0, self.g());
                return @intFromFloat(255.999 * byte);
            }

            pub fn bByte(self: *const Self) u8 {
                const byte: f32 = @min(1.0, self.b());
                return @intFromFloat(255.999 * byte);
            }
        } else struct {};

        // color RGBA
        pub usingnamespace if (dim == 4) struct {
            pub fn a(self: *const Self) T {
                return self.vector[3];
            }

            pub fn aByte(self: *const Self) u8 {
                const byte: f32 = @min(1.0, self.a());
                return @intFromFloat(255.999 * byte);
            }
        } else struct {};
    };
}

fn isFloatEqual(comptime T: type, x: T, y: T) bool {
    if (x == 0) {
        return std.math.approxEqAbs(T, x, y, std.math.floatEps(T));
    }

    return std.math.approxEqRel(T, x, y, std.math.floatEpsAt(T, 0.0));
}

pub const Vec2f = Vector(f32, 2);
pub const Vec3f = Vector(f32, 3);
pub const Vec4f = Vector(f32, 4);

pub const Point3 = Vec3f;

pub const ColorRgb = Vec3f;
pub const ColorRgba = Vec4f;

// Tests

test "initialization" {
    const test_vec: @Vector(3, f32) = .{ -1.0, 2.0, -3.0 };

    try expectEqual(test_vec, Vec3f.init(.{ -1.0, 2.0, -3.0 }).vector);

    try expectEqual(Vec3f.init(.{ 0.0, 0.0, 0.0 }), Vec3f.zero());
    try expectEqual(Vec3f.init(.{ 1.0, 1.0, 1.0 }), Vec3f.one());

    try expectEqual(Vec3f.init(.{ 42.0, 42.0, 42.0 }), Vec3f.splat(42.0));
}

test "vector length" {
    const test_vec: Vec3f = .init(.{ 1.5, 3.0, 4.0 });
    const unit_vector = try test_vec.unit();
    const element_type = @TypeOf(test_vec).elementType();

    // example unit vector
    try expectEqual(Vec3f.init(.{ 0.28734788, 0.57469577, 0.76626104 }), unit_vector);

    // vector lengths
    try expect(isFloatEqual(element_type, 27.25, test_vec.lengthSquared()));
    try expect(isFloatEqual(element_type, 5.2201533, test_vec.length()));
    try expect(isFloatEqual(element_type, 1.0, unit_vector.lengthSquared()));
    try expect(isFloatEqual(element_type, 1.0, unit_vector.length()));
    try expect(isFloatEqual(element_type, 0.0, Vec3f.zero().lengthSquared()));
    try expect(isFloatEqual(element_type, 0.0, Vec3f.zero().length()));

    // (almost) zero vector
    try expect(Vec3f.zero().isNearZero());
    try expect(Vec3f.init(.{ 0.00000001, 0, 0 }).isNearZero());
}

test "vector angles" {
    const test_vec1: Vec3f = .init(.{ 1.0, 2.0, 3.0 });
    const test_vec2: Vec3f = .init(.{ 4.0, 5.0, 6.0 });
    const test_vec3: Vec3f = .init(.{ 1.0, 0.0, 0.0 });
    const test_vec4: Vec3f = .init(.{ 0.0, 2.0, 3.0 });
    const element_type = @TypeOf(test_vec1).elementType();

    // example angle
    try expect(isFloatEqual(element_type, 0.2257264, test_vec1.angleRad(test_vec2)));
    try expect(isFloatEqual(element_type, 12.93317, test_vec1.angleDeg(test_vec2)));

    // perpendicular
    try expect(isFloatEqual(element_type, 90.0, test_vec3.angleDeg(test_vec4)));
    // parallel
    try expect(isFloatEqual(element_type, 0.0, test_vec3.angleRad(test_vec3)));
}

test "dimension change" {
    const test_vec1: Vec2f = .init(.{ 1.0, 2.0 });
    const test_vec2: Vec4f = .init(.{ 1.0, 2.0, 3.0, 4.0 });

    try expectEqual(
        Vec4f.init(.{ 1.0, 2.0, 0.0, 0.0 }),
        test_vec1.changeDimension(4, 0.0),
    );
    try expectEqual(
        Vec4f.init(.{ 1.0, 2.0, 8.0, 8.0 }),
        test_vec1.changeDimension(4, 8.0),
    );

    try expectEqual(Vec2f.init(.{ 1.0, 2.0 }), test_vec2.changeDimension(2, 0.0));
}

test "vector operations" {
    const test_vec: Vec3f = .init(.{ 1.0, -2.0, 3.0 });
    const test_vec_dot1: Vec3f = .init(.{ 1.0, 0.0, 0.0 });
    const test_vec_dot2: Vec3f = .init(.{ 0.0, 2.0, 3.0 });
    const test_vec3d: Vec3f = .init(.{ 2.0, 3.0, 4.0 });
    const test_vec2d1: Vec2f = .init(.{ 2.0, 3.0 });
    const test_vec2d2: Vec2f = .init(.{ 4.0, 1.0 });

    // basic operations
    try expectEqual(Vec3f.init(.{ 3.0, 1.0, 7.0 }), test_vec.addVec(test_vec3d));
    try expectEqual(Vec3f.init(.{ -1.0, -5.0, -1.0 }), test_vec.subtractVec(test_vec3d));

    // negate
    try expectEqual(Vec3f.init(.{ -1.0, 2.0, -3.0 }), test_vec.negate());

    // dot product
    try expectEqual(8.0, test_vec.dot(test_vec3d));
    try expectEqual(0.0, Vec3f.zero().dot(test_vec));
    try expectEqual(0.0, test_vec.dot(Vec3f.zero()));
    // perpendicular
    try expectEqual(0.0, test_vec_dot1.dot(test_vec_dot2));
    try expectEqual(true, test_vec_dot2.isPerpendicular(test_vec_dot1));
    try expectEqual(false, test_vec_dot1.isPerpendicular(test_vec));
    // parallel
    try expectEqual(28.0, Vec3f.init(.{ 1.0, 2.0, 3.0 }).dot(Vec3f.init(.{ 2.0, 4.0, 6.0 })));
    try expectEqual(-28.0, Vec3f.init(.{ -2.0, -4.0, -6.0 }).dot(Vec3f.init(.{ 1.0, 2.0, 3.0 })));
    // own dot product is squared length
    try expectEqual(test_vec.lengthSquared(), test_vec.dot(test_vec));

    // cross product 3D
    try expectEqual(
        Vec3f.init(.{ -3.0, 6.0, -3.0 }),
        test_vec3d.cross(Vec3f.init(.{ 5.0, 6.0, 7.0 })),
    );

    // cross product 2D
    try expectEqual(
        -10,
        test_vec2d1.cross(test_vec2d2),
    );
    try expectEqual(
        Vec3f.init(.{ 0.0, 0.0, -10.0 }),
        test_vec2d1.changeDimension(3, 0.0).cross(
            test_vec2d2.changeDimension(3, 0.0),
        ),
    );
}

test "scalar operations" {
    const test_vec = Vec3f.init(.{ -1.0, 2.0, -3.0 });

    try expectEqual(Vec3f.init(.{ 1.0, 4.0, -1.0 }), test_vec.add(2));
    try expectEqual(Vec3f.init(.{ -3.0, 0.0, -5.0 }), test_vec.subtract(2));
    try expectEqual(Vec3f.init(.{ -2.0, 4.0, -6.0 }), test_vec.multiply(2));
    try expectEqual(Vec3f.init(.{ -0.5, 1.0, -1.5 }), test_vec.divide(2));

    // division by zero
    try expectError(VecError.DivisionByZero, test_vec.divide(0.0));

    // no unit vector for zero vector
    try expectError(VecError.UnitVectorForZero, Vec3f.zero().unit());
}
