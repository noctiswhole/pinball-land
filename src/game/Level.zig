// TODO: move most of the point-management logic to LevelMesh
const Level = @This();
const Vector2 = @import("../data/Vector2.zig");
const std = @import("std");
const primitives = @import("../graphics/primitives.zig");
const sqlite = @import("sqlite");
const LevelMesh = @import("LevelMesh.zig");

const LevelGeometries = std.ArrayListUnmanaged(LevelMesh);

// Maybe want to give these points IDs or something
pub const Point = Vector2;
const SELECTION_ALLOWANCE: f32 = 0.4;
const DRAW_SELECTED_RADIUS: f32 = 0.2;

level_meshes: LevelGeometries = .empty,
level_mesh_names: std.ArrayListUnmanaged([]const u8) = .empty,
selected_point: ?*Point = null,
active_mesh_index: usize = 0,
level_id: usize = 0,

pub fn addPoint(self: *Level, allocator: std.mem.Allocator, point: Point) !void {
    self.selected_point = null;
    try self.level_meshes.items[self.active_mesh_index].addPoint(allocator, point);
}

pub fn removePoint(self: *Level, point_search: Point) bool {
    self.selected_point = null;
    for (0..self.level_meshes.items[self.active_mesh_index].points.items.len) |i| {
        const point = self.level_meshes.items[self.active_mesh_index].points.items[i];
        if ((point.x + SELECTION_ALLOWANCE > point_search.x and point.x - SELECTION_ALLOWANCE < point_search.x) and
            (point.y + SELECTION_ALLOWANCE > point_search.y and point.y - SELECTION_ALLOWANCE < point_search.y)) {
            _ = self.level_meshes.items[self.active_mesh_index].points.orderedRemove(i);
            return true;
        }
    }
    return false;
}

pub fn selectPoint(self: *Level, point_search: Point) bool {
    self.selected_point = null;
    for (self.level_meshes.items[self.active_mesh_index].points.items) |*point| {
        if ((point.x + SELECTION_ALLOWANCE > point_search.x and point.x - SELECTION_ALLOWANCE < point_search.x) and
            (point.y + SELECTION_ALLOWANCE > point_search.y and point.y - SELECTION_ALLOWANCE < point_search.y)) {
            self.selected_point = point;
            return true;
        }
    }
    return false;
}

pub fn drawPoints(self: Level) void {
    for (self.level_meshes.items) |mesh| {
        const draw_points: bool = self.level_meshes.items[self.active_mesh_index].id == mesh.id;
        mesh.drawPoints(draw_points);
    }
    if (self.selected_point) |spoint| {
        primitives.drawSphere(spoint.toVector3(), DRAW_SELECTED_RADIUS);
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

pub fn loadLevel(self: *Level, allocator: std.mem.Allocator, level_id: usize) !void {
    var db = try getDb("assets/asset.db");

    // load mesh groups
    {
        const query =
            \\ SELECT id, is_connected, is_loop, name FROM
            \\ level_meshes
            \\ WHERE level_id = ?
        ;
        var stmt = try db.prepare(query);
        defer stmt.deinit();

        const meshes = try stmt.all(struct {
            id: usize,
            is_connected: bool,
            is_loop: bool,
            name: []const u8,
        }, allocator, .{}, .{level_id});
        try self.level_meshes.ensureTotalCapacity(allocator, meshes.len);
        try self.level_mesh_names.ensureTotalCapacity(allocator, meshes.len);
        for (meshes) |mesh| {
            self.level_meshes.appendAssumeCapacity(.{
                .id = mesh.id,
                .is_connected = mesh.is_connected,
                .is_loop = mesh.is_loop,
            });
            self.level_mesh_names.appendAssumeCapacity(mesh.name);
        }
        self.level_id = level_id;
    }

    // load mesh points
    if (self.level_meshes.items.len > 0) {
        self.active_mesh_index = 0;
        const query =
            \\ SELECT x, y, level_mesh_id FROM
            \\ level_mesh_points
            \\ WHERE level_id = ? ORDER BY level_mesh_id, sort
        ;
        var stmt = try db.prepare(query);
        defer stmt.deinit();

        const points = try stmt.all(struct {
            x: f32,
            y: f32,
            level_mesh_id: usize,
        }, allocator, .{}, .{level_id});

        var mesh_index: usize = 0;
        // try self.level_meshes.items[self.active_mesh_index].points.ensureTotalCapacity(allocator, points.len);
        for (points) |point| {
            while (self.level_meshes.items[mesh_index].id != point.level_mesh_id) {
                mesh_index += 1;
                if (self.level_meshes.items.len <= mesh_index) {
                    std.debug.print("Invalid mesh index reference {d}", .{point.level_mesh_id});
                    return error.InvalidGeometryIndexReference;
                }
            }
            try self.level_meshes.items[mesh_index].points.append(allocator, .{ .x = point.x, .y = point.y });
        }
    }
}

pub fn deleteDbPoints(self: Level, db: *sqlite.Db) !void {
    const query =
        \\ DELETE FROM level_mesh_points
        \\ where level_id = ?
        ;
    var stmt = try db.prepare(query);
    defer stmt.deinit();
    try stmt.exec(.{}, .{self.level_id});
}

pub fn saveDbPoints(self: Level) !void {
    // TODO create resource that handles saving/loading levels
    var db = try getDb("assets/asset.db");
    try self.deleteDbPoints(&db);
    const len = self.level_meshes.items[self.active_mesh_index].points.items.len;
    if (len < 2) {
        return;
    }
    const query =
        \\ INSERT INTO level_mesh_points
        \\ (level_mesh_id, x, y, sort, level_id) values
        \\ (?, ?, ?, ?, ?)
        ;
    var stmt = try db.prepare(query);
    defer stmt.deinit();

    for (self.level_meshes.items) |mesh| {
        var index: usize = 0;
        for (0..len) |i| {
            stmt.reset();
            try stmt.exec(.{}, .{
                .level_mesh_id = mesh.id,
                .x = mesh.points.items[i].x,
                .y = mesh.points.items[i].y,
                .sort = index,
                .level_id = self.level_id,
            });
            index += 1;
        }
    }
}