const LevelGeometry = @This();
const std = @import("std");
const Vector2 = @import("../data/Vector2.zig");
const primitives = @import("../graphics/primitives.zig");

pub const Point = Vector2;
const LevelGeometryPointList = std.ArrayListUnmanaged(Point);
const DRAW_UNSELECTED_RADIUS: f32 = 0.1;

id: usize,
is_loop: bool,
is_connected: bool,
points: LevelGeometryPointList = .empty,

pub fn addPoint(self: *LevelGeometry, allocator: std.mem.Allocator, point: Point) !void {
    try self.points.append(allocator, point);
}

pub fn drawPoints(self: LevelGeometry, show_points: bool) void {
    // TODO:
    // TODO: unify iteration with the box2d-side iteration with a iterator
    const len = self.points.items.len;
    if (len < 2) {
        return;
    }

    if (show_points) {
        primitives.drawSphere(self.points.items[0].toVector3(), DRAW_UNSELECTED_RADIUS);
    }
    var index: usize = 1;
    while (index < len) {
        primitives.drawLine(self.points.items[index-1].toVector3(), self.points.items[index].toVector3());
        if (show_points) {
            primitives.drawSphere(self.points.items[index].toVector3(), DRAW_UNSELECTED_RADIUS);
        }
        index += 1;
    }
    index -= 1;
    if (self.is_connected) {
        primitives.drawLine(self.points.items[index].toVector3(), self.points.items[index].mirror().toVector3());
    }

    while (index > 0) {
        primitives.drawLine(self.points.items[index].mirror().toVector3(), self.points.items[index - 1].mirror().toVector3());
        index -= 1;
    }

    if (self.is_loop) {
        if (self.is_connected) {
            primitives.drawLine(self.points.items[0].toVector3(), self.points.items[0].mirror().toVector3());
        } else {
            primitives.drawLine(self.points.items[0].toVector3(), self.points.items[len - 1].toVector3());
            primitives.drawLine(self.points.items[0].mirror().toVector3(), self.points.items[len - 1].mirror().toVector3());
        }
    }
}