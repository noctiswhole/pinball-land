const rl = @import("raylib");
const box2d = @import("box2d.zig");
const game = @import("game.zig");
const std = @import("std");

const GameState = struct {};

pub fn main() anyerror!void {
    const screenWidth: i32 = 2560;
    const screenHeight: i32 = 1440;
    var world = box2d.Box2dWorld.init(rl.Vector2{ .x = 0, .y = -10.0 });
    defer world.deinit();


    // const shader = rl.loadShader(null, "assets/shaders/bloom.fs.glsl") catch {
    //     std.debug.print("idk man", .{});
    //     @panic("idk man");
    // };


    rl.initWindow(screenWidth, screenHeight, "Kirby Pinball Test");
    const shader_file = @embedFile("shaders/bloom.fs.glsl");
    const shader = try rl.loadShaderFromMemory(null, shader_file);

    const camera: rl.Camera2D = .{
        .target = .{ .x = -500, .y = -550 },
        .zoom = 1.2,
        .offset = .{ .x = 0, .y = 0 },
        .rotation = 0,
    };

    const camera3d: rl.Camera = .{
        .fovy = 20,
        .up = .{
            .x = 0,
            .y = 1,
            .z = 0,
        },
        .projection = .perspective,
        .position = .{
            .x = 0,
            .y = 180,
            .z = 1700,
        },
        .target = .{
            .x = 0,
            .y = 230,
            .z = 0,
        },
    };
    const B2D_TO_RL_RATIO = 20;

    const kirby_model = try rl.loadModel("assets/models/kirby_pinballin.glb");

    var cappy_tag: box2d.Tag = .{
        .name = "cappy1"
    };
    var cappy: game.Cappy = try game.Cappy.init(world,  .{
        .x = 0,
        .y = 10,
    }, "assets/models/cappy.glb", "assets/models/cappy_cap.glb", &cappy_tag);
    const flipper_mesh = rl.genMeshCube(3.5 * B2D_TO_RL_RATIO, 0.4 * B2D_TO_RL_RATIO, 2);
    const flipper_model = try rl.loadModelFromMesh(flipper_mesh);

    const render_texture = try rl.loadRenderTexture(screenWidth, screenHeight);
    rl.setTextureFilter(render_texture.texture, .anisotropic_16x);
    // defer model.unload();

    rl.gl.rlSetClipPlanes(1000, 2000);
    defer rl.closeWindow();
    rl.setTargetFPS(60);
    var kirby_rot: f32 = 0;

    while (!rl.windowShouldClose()) {
        // Update
        //----------------------------------------------------------------------------------
        world.step(1.0 / 60.0, 4);

        if (rl.isKeyDown(.z)) {
            world.activate_left();
        } else {
            world.deactivate_left();
        }
        if (rl.isKeyDown(.slash)) {
            world.activate_right();
        } else {
            world.deactivate_right();
        }

        const ball_position = world.ball_body.get_position();
        const ball_velocity = world.ball_body.get_velocity();
        kirby_rot -= ball_velocity.x;
        cappy.update();
        if (world.check_contact_events()) {
            cappy.damage();
        }


        //----------------------------------------------------------------------------------

        // Draw
        //----------------------------------------------------------------------------------



        {
            rl.beginTextureMode(render_texture);
            defer rl.endTextureMode();
            rl.beginMode3D(camera3d);
            defer rl.endMode3D();
            rl.clearBackground(.black);
            // const cappy_pos = cappy.body.get_position();
            // rl.drawSphere(.{
            //     .x = cappy_pos.x * B2D_TO_RL_RATIO,
            //     .y = cappy_pos.y * B2D_TO_RL_RATIO,
            //     .z = 0,
            // }, 0.8 * B2D_TO_RL_RATIO, .red);
            rl.drawModelEx(kirby_model, .{
                .x = ball_position.x * B2D_TO_RL_RATIO,
                .y = ball_position.y * B2D_TO_RL_RATIO,
                .z = 0,
            }, .{
                .x = 0,
                .y = 0,
                .z = 1,
            }, kirby_rot, .{
                .x = 20,
                .y = 20,
                .z = 20,
            }, .white);

            // Draw board
            rl.drawLine3D(.{
                .x = -10.0 * B2D_TO_RL_RATIO,
                .y = 3.0 * B2D_TO_RL_RATIO,
                .z = 0,
            }, .{
                .x = -10.0 * B2D_TO_RL_RATIO,
                .y = 25.0 * B2D_TO_RL_RATIO,
                .z = 0,
            }, .white);
            rl.drawLine3D(.{
                .x = -10.0 * B2D_TO_RL_RATIO,
                .y = 25.0 * B2D_TO_RL_RATIO,
                .z = 0,
            }, .{
                .x = 10.0 * B2D_TO_RL_RATIO,
                .y = 25.0 * B2D_TO_RL_RATIO,
                .z = 0,
            }, .white);
            rl.drawLine3D(.{
                .x = 10.0 * B2D_TO_RL_RATIO,
                .y = 25.0 * B2D_TO_RL_RATIO,
                .z = 0,
            }, .{
                .x = 10.0 * B2D_TO_RL_RATIO,
                .y = 3.0 * B2D_TO_RL_RATIO,
                .z = 0,
            }, .white);
            rl.drawLine3D(.{
                .x = 10.0 * B2D_TO_RL_RATIO,
                .y = 3.0 * B2D_TO_RL_RATIO,
                .z = 0,
            }, .{
                .x = 0 * B2D_TO_RL_RATIO,
                .y = -2.0 * B2D_TO_RL_RATIO,
                .z = 0,
            }, .white);
            rl.drawLine3D(.{
                .x = 0 * B2D_TO_RL_RATIO,
                .y = -2.0 * B2D_TO_RL_RATIO,
                .z = 0,
            }, .{
                .x = -10.0 * B2D_TO_RL_RATIO,
                .y = 3.0 * B2D_TO_RL_RATIO,
                .z = 0,
            }, .white);

            const flipper_left = world.flipper_left;
            const flipper_rot = world.get_rotation_joint_left();
            rl.drawModelEx(flipper_model, .{
                .x = flipper_left.get_position().x * B2D_TO_RL_RATIO,
                .y = flipper_left.get_position().y * B2D_TO_RL_RATIO,
                .z = 0,
            }, .{.x=0,.y=0,.z = 1}, flipper_rot * -1, .{
                .x = 1,
                .y = 1,
                .z = 1,
            }, .blue);


            const flipper_right = world.flipper_right;
            const flipper_right_rot = world.get_rotation_joint_right();
            rl.drawModelEx(flipper_model, .{
                .x = flipper_right.get_position().x * B2D_TO_RL_RATIO,
                .y = flipper_right.get_position().y * B2D_TO_RL_RATIO,
                .z = 0,
            }, .{.x=0,.y=0,.z = 1}, flipper_right_rot * -1, .{
                .x = 1,
                .y = 1,
                .z = 1,
            }, .blue);
            cappy.draw();
        }

        rl.beginDrawing();
        defer rl.endDrawing();
        rl.clearBackground(.black);

        {
            rl.beginShaderMode(shader);
            defer rl.endShaderMode();
            rl.drawTextureRec(render_texture.texture, .{
                .height = -screenHeight,
                .width = screenWidth,
                .x = 0,
                .y = 0,
            }, .{ .x = 0, .y = 0 }, .white);
        }



        if (false) {
            rl.beginMode2D(camera);
            defer rl.endMode2D();

            rl.drawCircleV(.{
                .x = ball_position.x * B2D_TO_RL_RATIO,
                .y = ball_position.y * B2D_TO_RL_RATIO * -1,
            }, 1 * B2D_TO_RL_RATIO, .red);
            // Draw board
            rl.drawLineEx(.{
                .x = -10.0 * B2D_TO_RL_RATIO,
                .y = 3.0 * B2D_TO_RL_RATIO * -1,
            }, .{
                .x = -10.0 * B2D_TO_RL_RATIO,
                .y = 25.0 * B2D_TO_RL_RATIO * -1,
            }, 2, .white);
            rl.drawLineEx(.{
                .x = -10.0 * B2D_TO_RL_RATIO,
                .y = 25.0 * B2D_TO_RL_RATIO * -1,
            }, .{
                .x = 10.0 * B2D_TO_RL_RATIO,
                .y = 25.0 * B2D_TO_RL_RATIO * -1,
            }, 2, .white);
            rl.drawLineEx(.{
                .x = 10.0 * B2D_TO_RL_RATIO,
                .y = 25.0 * B2D_TO_RL_RATIO * -1,
            }, .{
                .x = 10.0 * B2D_TO_RL_RATIO,
                .y = 3.0 * B2D_TO_RL_RATIO * -1,
            }, 2, .white);
            rl.drawLineEx(.{
                .x = 10.0 * B2D_TO_RL_RATIO,
                .y = 3.0 * B2D_TO_RL_RATIO * -1,
            }, .{
                .x = 0 * B2D_TO_RL_RATIO,
                .y = -2.0 * B2D_TO_RL_RATIO * -1,
            }, 2, .white);
            rl.drawLineEx(.{
                .x = 0 * B2D_TO_RL_RATIO,
                .y = -2.0 * B2D_TO_RL_RATIO * -1,
            }, .{
                .x = -10.0 * B2D_TO_RL_RATIO,
                .y = 3.0 * B2D_TO_RL_RATIO * -1,
            }, 2, .white);

            const flipper_left = world.flipper_left;
            const flipper_rot = world.get_rotation_joint_left();
            rl.drawRectanglePro(.{
                .height = 0.4 * B2D_TO_RL_RATIO,
                .width = 3.5 * B2D_TO_RL_RATIO,
                .x = flipper_left.get_position().x * B2D_TO_RL_RATIO,
                .y = (flipper_left.get_position().y + 0.2) * B2D_TO_RL_RATIO * -1,
            }, .{
                .x = 2.0 * B2D_TO_RL_RATIO,
                .y = 0,
            }, flipper_rot, .blue);

            const flipper_right = world.flipper_right;
            const flipper_right_rot = world.get_rotation_joint_right();
            rl.drawRectanglePro(.{
                .height = 0.4 * B2D_TO_RL_RATIO,
                .width = 3.5 * B2D_TO_RL_RATIO,
                .x = flipper_right.get_position().x * B2D_TO_RL_RATIO,
                .y = (flipper_right.get_position().y - 0.2) * B2D_TO_RL_RATIO * -1,
            }, .{
                .x = 2.0 * B2D_TO_RL_RATIO,
                .y = 0,
            }, flipper_right_rot, .blue);
        }
        rl.drawText("Pinball Test", 10, 10, 20, .white);

        //----------------------------------------------------------------------------------
    }
}
