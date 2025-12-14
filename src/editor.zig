const std = @import("std");
const dvui = @import("dvui");
const Vector2 = @import("data/Vector2.zig");
const RaylibBackend = @import("raylib-zig-backend");
pub const rl = RaylibBackend.raylib;
pub const raygui = RaylibBackend.raygui;
const Level = @import("game/Level.zig");
const struct_ui = dvui.struct_ui;

comptime {
    std.debug.assert(@hasDecl(RaylibBackend, "RaylibBackend"));
}

fn drawGrid(cam_pos: Vector2) void {
    const x: i32 = @intFromFloat(cam_pos.x);
    const y: i32 = @intFromFloat(cam_pos.y);
    const x_offset: f32 = @floatFromInt(x);
    const y_offset: f32 = @floatFromInt(y);
    const LINE_COLOR: rl.Color = rl.getColor(0x202020ff);
    const LINE_INTERVAL_COLOR: rl.Color = rl.getColor(0x151515ff);
    const LINE_X_COLOR: rl.Color = .maroon;
    const LINE_Y_COLOR: rl.Color = .dark_green;

    var i: f32 = -30;
    while (i < 30) {
        // y lines
        for (1..4) |j| {
            rl.drawLine3D(.{
                .x = i + (0.25 * @as(f32, @floatFromInt(j))) + x_offset,
                .y = -100 + y_offset,
                .z = -10,
            }, .{
                .x = i + (0.25 * @as(f32, @floatFromInt(j))) + x_offset,
                .y = 100 + y_offset,
                .z = -10,
            }, LINE_INTERVAL_COLOR);
        }

        const line_color_y: rl.Color = if (i + x_offset == 0) LINE_Y_COLOR else LINE_COLOR;

        rl.drawLine3D(.{
            .x = i + x_offset,
            .y = -100 + y_offset,
            .z = -10,
        }, .{
            .x = i + x_offset,
            .y = 100 + y_offset,
            .z = -10,
        }, line_color_y);

        // x lines
        for (1..4) |j| {
            rl.drawLine3D(.{
                .x = -100 + x_offset,
                .y = i + (0.25 * @as(f32, @floatFromInt(j))) + y_offset,
                .z = -10,
            }, .{
                .x = 100 + x_offset,
                .y = i + (0.25 * @as(f32, @floatFromInt(j))) + y_offset,
                .z = -10,
            }, LINE_INTERVAL_COLOR);
        }

        const line_color_x: rl.Color = if (i + y_offset == 0) LINE_X_COLOR else LINE_COLOR;

        rl.drawLine3D(.{
            .x = -100 + x_offset,
            .y = i + y_offset,
            .z = -10,
        }, .{
            .x = 100 + x_offset,
            .y = i + y_offset,
            .z = -10,
        }, line_color_x);
        i += 1;
    }
}
pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.smp_allocator);
    const allocator = arena.allocator();
    defer arena.deinit();

    if (@import("builtin").os.tag == .windows) { // optional
        // on windows graphical apps have no console, so output goes to nowhere - attach it manually. related: https://github.com/ziglang/zig/issues/4196
        try dvui.Backend.Common.windowsAttachConsole();
    }
    RaylibBackend.enableRaylibLogging();
    var gpa_instance = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa = gpa_instance.allocator();

    defer _ = gpa_instance.deinit();

    // create OS window directly with raylib
    rl.setConfigFlags(.{
        .window_resizable = true,
        .vsync_hint = true,
    });
    rl.initWindow(1920, 1080, "DVUI Raylib Ontop Example");
    defer rl.closeWindow();

    // init Raylib backend
    // init() means the app owns the window (and must call CloseWindow itself)
    var backend = RaylibBackend.init(gpa);
    defer backend.deinit();
    backend.log_events = true;

    // init dvui Window (maps onto a single OS window)
    // OS window is managed by raylib, not dvui
    var win = try dvui.Window.init(@src(), gpa, backend.backend(), .{});
    defer win.deinit();

    var cam_pos: Vector2 = .{ .x = 0, .y = 12 };

    var camera3d: rl.Camera = .{
        .fovy = 30,
        .up = .{
            .x = 0,
            .y = 1,
            .z = 0,
        },
        .projection = .orthographic,
        .position = .{
            .x = cam_pos.x,
            .y = cam_pos.y,
            .z = 20,
        },
        .target = .{
            .x = cam_pos.x,
            .y = cam_pos.y,
            .z = 0,
        },
    };

    var level: Level = .{};
    try level.loadPoints(allocator);

    // defer level.deinit();
    while (!rl.windowShouldClose()) {
        const mouse_pos: rl.Vector2 = rl.getMousePosition();
        const ray = rl.getScreenToWorldRay(mouse_pos, camera3d);

        const collision = rl.getRayCollisionQuad(
            ray,
            .{ .x = -100, .y = -100, .z = 0 },
            .{.x = -100, .y = 100, .z = 0},
            .{ .x = 100, .y = 100, .z = 0 },
            .{ .x = 100, .y = -100, .z = 0 },
        );

        // marks the beginning of a frame for dvui, can call dvui functions after this
        try win.begin(std.time.nanoTimestamp());

        // send all Raylib events to dvui for processing
        try backend.addAllEvents(&win);

        if (backend.shouldBlockRaylibInput()) {
            // NOTE: I am using raygui here because it has a simple lock-unlock system
            // Non-raygui raylib apps could also easily implement such a system
            raygui.lock();
        } else {
            raygui.unlock();
        }

        if (!raygui.isLocked()) {
            // TODO: build event manager
            if (rl.isKeyDown(.left_shift)) {
                if (rl.isMouseButtonPressed(.left)) {
                    try level.addPoint(allocator, .{ .x = @round(collision.point.x * 4) / 4, .y = @round(collision.point.y * 4) / 4 });
                }
                if (rl.isMouseButtonDown(.right)) {
                    _ = level.removePoint(
                        .{
                            .x = collision.point.x,
                            .y = collision.point.y,
                        }
                    );
                }
            } else {
                if (rl.isMouseButtonPressed(.left)) {
                    _ = level.selectPoint(.{
                        .x = collision.point.x,
                        .y = collision.point.y,
                    });
                } else if (rl.isMouseButtonDown(.left)) {
                    std.debug.print("clicked {d}, {d}, {d}\n", .{collision.point.x, collision.point.y, collision.point.z});
                    if (level.selected_point) |point| {
                        point.x = @round(collision.point.x * 4) / 4;
                        point.y = @round(collision.point.y * 4) / 4;
                    }
                }

                if (rl.isMouseButtonDown(.middle)) {
                    const mouse_delta = rl.getMouseDelta();
                    cam_pos.x -= mouse_delta.x/30;
                    cam_pos.y += mouse_delta.y/30;

                    camera3d.position.x = cam_pos.x;
                    camera3d.position.y = cam_pos.y;
                    camera3d.target.x = cam_pos.x;
                    camera3d.target.y = cam_pos.y;
                }
            }
        }

        rl.beginDrawing();
        rl.clearBackground(RaylibBackend.dvuiColorToRaylib(dvui.Color.black));
        {
            rl.beginMode3D(camera3d);
            defer rl.endMode3D();
            drawGrid(cam_pos);
            level.drawPoints();
        }

        try dvuiStuff(level.selected_point, collision.point, &level);

        // marks end of dvui frame, don't call dvui functions after this
        // - sends all dvui stuff to backend for rendering, must be called before EndDrawing()
        _ = try win.end(.{});

        // cursor management
        if (win.cursorRequestedFloating()) |cursor| {
            // cursor is over floating window, dvui sets it
            backend.setCursor(cursor);
        } else {
            // cursor should be handled by application
            backend.setCursor(.arrow);
        }

        rl.endDrawing();
    }
}

fn colorPicker(result: *dvui.Color) void {
    _ = dvui.spacer(@src(), .{ .min_size_content = .all(10) });
    {
        var overlay = dvui.overlay(@src(), .{ .min_size_content = .{ .w = 100, .h = 100 } });
        defer overlay.deinit();

        const bounds = overlay.data().contentRectScale().r;
        const ray_bounds: rl.Rectangle = .{
            .x = bounds.x,
            .y = bounds.y,
            .width = bounds.w,
            .height = bounds.h,
        };
        var c_color: rl.Color = RaylibBackend.dvuiColorToRaylib(result.*);
        _ = raygui.colorPicker(ray_bounds, "Pick Color", &c_color);
        result.* = RaylibBackend.raylibColorToDvui(c_color);
    }

    const color_hex = result.toHexString();

    {
        var hbox = dvui.box(@src(), .{ .dir = .horizontal }, .{});
        defer hbox.deinit();

        dvui.labelNoFmt(@src(), &color_hex, .{}, .{
            .color_text = result.*,
            .gravity_y = 0.5,
        });

        const copy = dvui.button(@src(), "Copy", .{}, .{});

        if (copy) {
            dvui.clipboardTextSet(&color_hex);
            dvui.toast(@src(), .{ .message = "Copied!" });
        }
    }
}

fn dvuiStuff(point: ?*Vector2, mouse_pos: rl.Vector3, level: *Level) !void {
    // var float = dvui.floatingWindow(@src(), .{}, .{ .max_size_content = .{ .w = 400, .h = 400 } });
    // defer float.deinit();

    // float.dragAreaSet(dvui.windowHeader("Floating Window", "", null));
    //
    //
    var show_interface: bool = true;
    show_interface = show_interface;
    var float = dvui.floatingWindow(
        @src(),
        .{
            .open_flag = &show_interface,
            .center_on = .{
                .w = 200,
                .h = 980,
            }
        },
        .{
            .expand = .both,
            .max_size_content = .width(200),
            .tag = "point",
            .rect = .{
                .x = 0,
                .y = 0,
                .w = 200,
                .h = 980,
            }
        });
    defer float.deinit();
    _ = dvui.windowHeader("Properties", "", null);
    var vbox = dvui.box(@src(), .{.dir = .vertical}, .{
        .style = .window,
        .background = true,
        .expand = .vertical,
        .max_size_content = .width(@as(f32, @floatFromInt(rl.getScreenWidth())) * 0.2),
    });
    defer vbox.deinit();

    var scroll = dvui.scrollArea(@src(), .{}, .{ .expand = .both });
    defer scroll.deinit();

    if (point) |p| {
        // if (false) {
        //
        //     const structui_options: dvui.struct_ui.StructOptions(Vector2) = .initWithDefaults(.{
        //         .x = .{ .number = .{ .min = 0, .max = 50, .widget_type = .slider } },
        //         .y = .{ .number = .{ .min = -100, .max = 100, .widget_type = .slider } },
        //     }, null);
        //     var alignment: dvui.Alignment = .init(@src(), 0);
        //     defer alignment.deinit();
        //     _ = struct_ui.displayStruct(@src(), "x", p, 1, .{ .standard = .{} }, .{structui_options}, &alignment);
        // }
        _ = mouse_pos;

        // var float = dvui.floatingWindow(@src(), .{ .center_on = .{ .x = 100, .y = 100, .w = 100, .h = 100 }, .open_flag = &show_interface }, .{ .expand = .both, .max_size_content = .width(200), .tag = "point" });
        // defer float.deinit();

            // const structui_options: dvui.struct_ui.StructOptions(Vector2) = .initWithDefaults(.{
            //     .x = .{ .number = .{ .min = 0, .max = 50, .widget_type = .slider } },
            //     .y = .{ .number = .{ .min = -100, .max = 100, .widget_type = .slider } },
            // }, null);
        dvui.structUI(@src(), "Point", p, 1, .{});
    }

    // var tl = dvui.textLayout(@src(), .{}, .{ .expand = .horizontal, .font_style = .title_4 });
    // const lorem = "This example shows how to use dvui for floating windows on top of an existing application.";
    // tl.addText(lorem, .{});
    // tl.deinit();

    // var tl2 = dvui.textLayout(@src(), .{}, .{ .expand = .horizontal });
    // tl2.addText("The dvui is painting only floating windows and dialogs.", .{});
    // tl2.addText("\n\n", .{});
    // tl2.addText("Framerate is managed by the application (in this demo capped at vsync).", .{});
    // tl2.addText("\n\n", .{});
    // tl2.addText("Cursor is only being set by dvui for floating windows.", .{});
    // tl2.addText("\n\n", .{});
    // if (dvui.useFreeType) {
    //     tl2.addText("Fonts are being rendered by FreeType 2.", .{});
    // } else {
    //     tl2.addText("Fonts are being rendered by stb_truetype.", .{});
    // }
    // tl2.deinit();

    const label = if (dvui.Examples.show_demo_window) "Hide Demo Window" else "Show Demo Window";
    if (dvui.button(@src(), label, .{}, .{})) {
        dvui.Examples.show_demo_window = !dvui.Examples.show_demo_window;
    }

    if (dvui.button(@src(), "Debug Window", .{}, .{})) {
        dvui.toggleDebugWindow();
    }

    if (dvui.button(@src(), "Save Points", .{}, .{})) {
        try level.savePoints();
    }

    // look at demo() for examples of dvui widgets, shows in a floating window
    dvui.Examples.demo();
}