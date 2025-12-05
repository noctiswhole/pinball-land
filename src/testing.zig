const rl = @import("raylib");

pub fn createWindow() void {
    const screenWidth: i32 = 2560;
    const screenHeight: i32 = 1440;
    rl.initWindow(screenWidth, screenHeight, "Test Window");
}

pub fn destroyWindow() void {
    rl.closeWindow();
}
