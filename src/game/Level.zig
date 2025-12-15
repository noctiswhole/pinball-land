// TODO: move most of the point-management logic to LevelGeometry
const Level = @This();
const Vector2 = @import("../data/Vector2.zig");
const std = @import("std");
const primitives = @import("../graphics/primitives.zig");
const sqlite = @import("sqlite");
const LevelGeometry = @import("LevelGeometry.zig");

const LevelGeometries = std.ArrayListUnmanaged(LevelGeometry);

// Maybe want to give these points IDs or something
pub const Point = Vector2;
const SELECTION_ALLOWANCE: f32 = 0.4;
const DRAW_UNSELECTED_RADIUS: f32 = 0.1;
const DRAW_SELECTED_RADIUS: f32 = 0.2;

level_geometry: LevelGeometry = .{
    .id = 1,
    .is_connected = false,
    .is_loop = false,
},
level_geometries: LevelGeometries = .empty,
selected_point: ?*Point = null,

pub fn addPoint(self: *Level, allocator: std.mem.Allocator, point: Point) !void {
    self.selected_point = null;
    try self.level_geometry.addPoint(allocator, point);
}

pub fn removePoint(self: *Level, point_search: Point) bool {
    self.selected_point = null;
    for (0..self.level_geometry.points.items.len) |i| {
        const point = self.level_geometry.points.items[i];
        if ((point.x + SELECTION_ALLOWANCE > point_search.x and point.x - SELECTION_ALLOWANCE < point_search.x) and
            (point.y + SELECTION_ALLOWANCE > point_search.y and point.y - SELECTION_ALLOWANCE < point_search.y)) {
            _ = self.level_geometry.points.orderedRemove(i);
            return true;
        }
    }
    return false;
}

pub fn selectPoint(self: *Level, point_search: Point) bool {
    self.selected_point = null;
    for (self.level_geometry.points.items) |*point| {
        if ((point.x + SELECTION_ALLOWANCE > point_search.x and point.x - SELECTION_ALLOWANCE < point_search.x) and
            (point.y + SELECTION_ALLOWANCE > point_search.y and point.y - SELECTION_ALLOWANCE < point_search.y)) {
            self.selected_point = point;
            return true;
        }
    }
    return false;
}

pub fn drawPoints(self: Level) void {
    // TODO: unify iteration with the box2d-side iteration with a iterator
    const len = self.level_geometry.points.items.len;
    if (len < 2) {
        return;
    }

    primitives.drawSphere(self.level_geometry.points.items[0].toVector3(), DRAW_UNSELECTED_RADIUS);
    var index: usize = 1;
    while (index < len) {
        primitives.drawLine(self.level_geometry.points.items[index-1].toVector3(), self.level_geometry.points.items[index].toVector3());
        primitives.drawSphere(self.level_geometry.points.items[index].toVector3(), DRAW_UNSELECTED_RADIUS);
        index += 1;
    }
    index -= 1;
    if (self.selected_point) |spoint| {
        primitives.drawSphere(spoint.toVector3(), DRAW_SELECTED_RADIUS);
    }
    primitives.drawLine(self.level_geometry.points.items[index].toVector3(), self.level_geometry.points.items[index].mirror().toVector3());

    while (index > 0) {
        primitives.drawLine(self.level_geometry.points.items[index].mirror().toVector3(), self.level_geometry.points.items[index - 1].mirror().toVector3());
        index -= 1;
    }
}
fn getDb(file_path: [:0]const u8) !sqlite.Db {
    const db = try sqlite.Db.init(.{
        .mode =  sqlite.Db.Mode{
            .File = file_path,
        },
        .open_flags = .{ .create = true, .write = true },
        .threading_mode = .MultiThread,
    });
    return db;

}

const Vec2 = extern struct {
    x: f32,
    y: f32,
};

pub fn loadLevel(self: *Level, allocator: std.mem.Allocator, level_id: usize) !void {
    var db = try getDb("assets/asset.db");

    {
        const query =
            \\ SELECT id, is_connected, is_loop FROM
            \\ level_geometry
            \\ WHERE level_id = ?
        ;
        var stmt = try db.prepare(query);
        defer stmt.deinit();

        const geometries = try stmt.all(struct {
            id: usize,
            is_connected: bool,
            is_loop: bool,
        }, allocator, .{}, .{level_id});
        try self.level_geometries.ensureTotalCapacity(allocator, geometries.len);
        for (geometries) |geometry| {
            self.level_geometries.appendAssumeCapacity(.{
                .id = geometry.id,
                .is_connected = geometry.is_connected,
                .is_loop = geometry.is_loop,
            });
        }
    }

    if (self.level_geometries.items.len > 0) {
        const query =
            \\ SELECT x, y, level_geometry_id FROM
            \\ level_geometry
            \\ join level_geometry_points
            \\ on level_geometry_points.level_geometry_id = level_geometry.id
            \\ WHERE level_id = ? ORDER BY level_geometry_id, sort
        ;
        var stmt = try db.prepare(query);
        defer stmt.deinit();

        const points = try stmt.all(struct {
            x: f32,
            y: f32,
            level_geometry_id: usize,
        }, allocator, .{}, .{level_id});

        var geometry_index: usize = 0;
        // try self.level_geometry.points.ensureTotalCapacity(allocator, points.len);
        for (points) |point| {
            while (self.level_geometries.items[geometry_index].id != point.level_geometry_id) {
                geometry_index += 1;
                if (self.level_geometries.items.len >= geometry_index) {
                    std.debug.print("Invalid geometry index reference {d}", .{point.level_geometry_id});
                    return error.InvalidGeometryIndexReference;
                }
            }
            try self.level_geometries.items[geometry_index].points.append(allocator, .{ .x = point.x, .y = point.y });
        }
    }
}

pub fn loadPoints(self: *Level, allocator: std.mem.Allocator, level_id: usize) !void {
    var db = try getDb("assets/asset.db");
    const query =
        \\ SELECT x, y, level_geometry_id FROM
        \\ level_geometry
        \\ join level_geometry_points
        \\ on level_geometry_points.level_geometry_id = level_geometry.id
        \\ WHERE level_id = ? ORDER BY level_geometry_id, sort
        ;
    var stmt = try db.prepare(query);
    defer stmt.deinit();

    const points = try stmt.all(struct {
        x: f32,
        y: f32,
        level_geometry_id: usize,
    }, allocator, .{}, .{level_id});
    try self.level_geometry.points.ensureTotalCapacity(allocator, points.len);
    for (points) |point| {
        self.level_geometry.points.appendAssumeCapacity(.{ .x = point.x, .y = point.y });
    }
}

pub fn deletePoints(db: *sqlite.Db) !void {
    // TODO: remove hard coded id
    const query =
        \\ DELETE FROM level_geometry_points
        \\ where level_geometry_id = 1
        ;
    var stmt = try db.prepare(query);
    defer stmt.deinit();
    try stmt.exec(.{}, .{});
}

pub fn savePoints(self: Level) !void {
    // TODO create resource that handles saving/loading levels
    var db = try getDb("assets/asset.db");
    try deletePoints(&db);
    const len = self.level_geometry.points.items.len;
    if (len < 2) {
        return;
    }
    const query =
        \\ INSERT INTO level_geometry_points
        \\ (level_geometry_id, x, y, sort) values
        \\ (?, ?, ?, ?)
        ;
    var stmt = try db.prepare(query);
    defer stmt.deinit();

    var index: usize = 0;
    for (0..len) |i| {
        stmt.reset();
        try stmt.exec(.{}, .{
            .level_id = 1,
            .x = self.level_geometry.points.items[i].x,
            .y = self.level_geometry.points.items[i].y,
            .sort = index,
        });
        index += 1;
    }
}