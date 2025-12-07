const Vector3 = @This();
const rl = @import("raylib");

x: f32 = 0,
y: f32 = 0,
z: f32 = 0,

pub fn init(x: f32, y: f32, z: f32) Vector3 {
    return .{
        .x = x,
        .y = y,
        .z = z,
    };
}

pub fn toRl(self: Vector3) rl.Vector3 {
    return .{
        .x = self.x,
        .y = self.y,
        .z = self.z,
    };
}