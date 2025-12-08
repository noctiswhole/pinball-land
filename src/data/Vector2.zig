const Vector2 = @This();
const rl = @import("raylib");
const Vector3 = @import("Vector3.zig");

x: f32 = 0,
y: f32 = 0,

pub fn init(x: f32, y: f32) Vector2 {
    return .{
        .x = x,
        .y = y,
    };
}

pub fn toRl(self: Vector2) rl.Vector2 {
    return .{
        .x = self.x,
        .y = self.y,
    };
}

pub fn toVector3(self: Vector2) Vector3 {
    return .{
        .x = self.x,
        .y = self.y,
        .z = 0,
    };
}

pub fn mirror(self: Vector2) Vector2 {
    return .{
        .x = self.x * -1,
        .y = self.y
    };
}