const Level = @This();
const Vector2 = @import("../data/Vector2.zig");
const std = @import("std");
const primitives = @import("../graphics/primitives.zig");

// Maybe want to give these points IDs or something
pub const Point = Vector2;
const LevelPointList = std.ArrayListUnmanaged(Point);
const SELECTION_ALLOWANCE: f32 = 1.0;

point_list: LevelPointList = .empty,
selected_point: ?*Point = null,

// pub fn init() Level {
//     return .{
//
//     };
// }

pub fn addPoint(self: *Level, allocator: std.mem.Allocator, point: Point) !void {
    self.selected_point = null;
    try self.point_list.append(allocator, point);
}

//
pub fn selectPoint(self: *Level, point_search: Point) bool {
    self.selected_point = null;
    for (self.point_list.items) |*point| {
        if ((point.x + SELECTION_ALLOWANCE > point_search.x and point.x - SELECTION_ALLOWANCE < point.x) and
            (point.y + SELECTION_ALLOWANCE > point_search.y and point.y - SELECTION_ALLOWANCE < point.y)) {
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

    var index: usize = 1;
    while (index < len) {
        primitives.drawLine(self.point_list.items[index-1].toVector3(), self.point_list.items[index].toVector3());
        index += 1;
    }
    index -= 1;

    primitives.drawLine(self.point_list.items[index].toVector3(), self.point_list.items[index].mirror().toVector3());

    while (index > 0) {
        primitives.drawLine(self.point_list.items[index].mirror().toVector3(), self.point_list.items[index - 1].mirror().toVector3());
        index -= 1;
    }
}