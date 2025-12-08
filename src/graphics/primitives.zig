const rl = @import("raylib");
const Vector3 = @import("../data/Vector3.zig");

pub fn drawLine(start: Vector3, end: Vector3) void {
    rl.drawLine3D(start.toRl(), end.toRl(), .red);
}

pub fn drawSphere(position: Vector3, radius: f32) void {
    rl.drawSphere(position.toRl(), radius, .red);
}