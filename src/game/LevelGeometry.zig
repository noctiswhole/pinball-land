const LevelGeometry = @This();
const std = @import("std");
const Vector2 = @import("../data/Vector2.zig");

pub const Point = Vector2;
const LevelGeometryPointList = std.ArrayListUnmanaged(Point);

id: usize,
is_loop: bool,
is_connected: bool,
points: LevelGeometryPointList = .empty,

pub fn addPoint(self: *LevelGeometry, allocator: std.mem.Allocator, point: Point) !void {
    try self.points.append(allocator, point);
}