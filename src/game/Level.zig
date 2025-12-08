const Level = @This();
const Vector2 = @import("../data/Vector2.zig");
const std = @import("std");
const primitives = @import("../graphics/primitives.zig");

// Maybe want to give these points IDs or something
pub const Point = Vector2;
const LevelPointList = std.ArrayListUnmanaged(Point);
const SELECTION_ALLOWANCE: f32 = 0.4;
const DRAW_UNSELECTED_RADIUS: f32 = 0.1;
const DRAW_SELECTED_RADIUS: f32 = 0.2;

point_list: LevelPointList = .empty,
selected_point: ?*Point = null,

pub fn addPoint(self: *Level, allocator: std.mem.Allocator, point: Point) !void {
    self.selected_point = null;
    try self.point_list.append(allocator, point);
}

pub fn selectPoint(self: *Level, point_search: Point) bool {
    self.selected_point = null;
    for (self.point_list.items) |*point| {
        if ((point.x + SELECTION_ALLOWANCE > point_search.x and point.x - SELECTION_ALLOWANCE < point_search.x) and
            (point.y + SELECTION_ALLOWANCE > point_search.y and point.y - SELECTION_ALLOWANCE < point_search.y)) {
            self.selected_point = point;
            return true;
        }
    }
    return false;
}

pub fn drawPoints(self: Level) void {
    const len = self.point_list.items.len;
    if (len < 2) {
        return;
    }

    primitives.drawSphere(self.point_list.items[0].toVector3(), DRAW_UNSELECTED_RADIUS);
    var index: usize = 1;
    while (index < len) {
        primitives.drawLine(self.point_list.items[index-1].toVector3(), self.point_list.items[index].toVector3());
        primitives.drawSphere(self.point_list.items[index].toVector3(), DRAW_UNSELECTED_RADIUS);
        index += 1;
    }
    index -= 1;
    if (self.selected_point) |spoint| {
        primitives.drawSphere(spoint.toVector3(), DRAW_SELECTED_RADIUS);
    }
    primitives.drawLine(self.point_list.items[index].toVector3(), self.point_list.items[index].mirror().toVector3());

    while (index > 0) {
        primitives.drawLine(self.point_list.items[index].mirror().toVector3(), self.point_list.items[index - 1].mirror().toVector3());
        index -= 1;
    }
}