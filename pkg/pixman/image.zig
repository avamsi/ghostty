const std = @import("std");
const c = @import("c.zig");
const pixman = @import("main.zig");

pub const Image = opaque {
    pub fn createBitsNoClear(
        format: pixman.FormatCode,
        width: c_int,
        height: c_int,
        bits: [*]u32,
        stride: c_int,
    ) pixman.Error!*Image {
        return @ptrCast(?*Image, c.pixman_image_create_bits_no_clear(
            @enumToInt(format),
            width,
            height,
            bits,
            stride,
        )) orelse return pixman.Error.PixmanFailure;
    }

    pub fn unref(self: *Image) bool {
        return c.pixman_image_unref(@ptrCast(*c.pixman_image_t, self)) == 1;
    }

    /// A variant of getDataUnsafe that sets the length of the slice to
    /// height * stride. Its possible the buffer is larger but this is the
    /// known safe values. If you KNOW the buffer is larger you can use the
    /// unsafe variant.
    pub fn getData(self: *Image) []u32 {
        const height = self.getHeight();
        const stride = self.getStride();
        const ptr = self.getDataUnsafe();
        const len = @intCast(usize, height * stride);
        return ptr[0..len];
    }

    pub fn getDataUnsafe(self: *Image) [*]u32 {
        return c.pixman_image_get_data(@ptrCast(*c.pixman_image_t, self));
    }

    pub fn getHeight(self: *Image) c_int {
        return c.pixman_image_get_height(@ptrCast(*c.pixman_image_t, self));
    }

    pub fn getStride(self: *Image) c_int {
        return c.pixman_image_get_stride(@ptrCast(*c.pixman_image_t, self));
    }

    pub fn fillBoxes(
        self: *Image,
        op: pixman.Op,
        color: pixman.Color,
        boxes: []const pixman.Box32,
    ) pixman.Error!void {
        if (c.pixman_image_fill_boxes(
            @enumToInt(op),
            @ptrCast(*c.pixman_image_t, self),
            @ptrCast(*const c.pixman_color_t, &color),
            @intCast(c_int, boxes.len),
            @ptrCast([*c]const c.pixman_box32_t, boxes.ptr),
        ) == 0) return pixman.Error.PixmanFailure;
    }

    pub fn rasterizeTrapezoid(
        self: *Image,
        trap: pixman.Trapezoid,
        x_off: c_int,
        y_off: c_int,
    ) void {
        c.pixman_rasterize_trapezoid(
            @ptrCast(*c.pixman_image_t, self),
            @ptrCast(*const c.pixman_trapezoid_t, &trap),
            x_off,
            y_off,
        );
    }
};

test "create and destroy" {
    const testing = std.testing;
    const alloc = testing.allocator;

    const width = 10;
    const height = 10;
    const format: pixman.FormatCode = .g1;
    const stride = format.strideForWidth(width);

    const len = height * @intCast(usize, stride);
    var data = try alloc.alloc(u32, len);
    defer alloc.free(data);
    std.mem.set(u32, data, 0);
    const img = try Image.createBitsNoClear(.g1, width, height, data.ptr, stride);
    try testing.expectEqual(@as(c_int, height), img.getHeight());
    try testing.expectEqual(@as(c_int, stride), img.getStride());
    try testing.expect(img.getData().len == height * stride);
    try testing.expect(img.unref());
}

test "fill boxes a1" {
    const testing = std.testing;
    const alloc = testing.allocator;

    // Dimensions
    const width = 100;
    const height = 100;
    const format: pixman.FormatCode = .a1;
    const stride = format.strideForWidth(width);

    // Image
    const len = height * @intCast(usize, stride);
    var data = try alloc.alloc(u32, len);
    defer alloc.free(data);
    std.mem.set(u32, data, 0);
    const img = try Image.createBitsNoClear(format, width, height, data.ptr, stride);
    defer _ = img.unref();

    // Fill
    const color: pixman.Color = .{ .red = 0xFFFF, .green = 0xFFFF, .blue = 0xFFFF, .alpha = 0xFFFF };
    const boxes = &[_]pixman.Box32{
        .{
            .x1 = 0,
            .y1 = 0,
            .x2 = width,
            .y2 = height,
        },
    };
    try img.fillBoxes(.src, color, boxes);
}
