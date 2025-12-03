
const rl = @import("raylib");
const c = @cImport({
    @cInclude("box2d/box2d.h");
});
const entities = @import("entities.zig");
const std = @import("std");
const PTM_RATIO: f32 = 50.0;
pub const B2D_TO_RL_RATIO = 20;

pub const Tag = struct {
    entity: entities.Entity,
};

pub fn vec2_rlToB2d(vec2: rl.Vector2) c.b2Vec2 {
    return c.b2Vec2{
        .x = vec2.x,
        .y = vec2.y,
    };
}
// TODO: apply ratio to vector automatically....
fn vec2_b2dToRl(vec2: c.b2Vec2) rl.Vector2 {
    return rl.Vector2{
        .x = vec2.x,
        .y = vec2.y,
    };
}

pub fn create_circle_shape(body: Box2dBody, radius: f32, restitution: f32, tag: *const Tag) c.b2ShapeId {
    const circle: c.b2Circle = .{
        .center = c.b2Vec2_zero,
        .radius = radius,
    };
    var shape_def: c.b2ShapeDef = c.b2DefaultShapeDef();
    shape_def.material.restitution = restitution;
    shape_def.enableContactEvents = true;
    shape_def.userData = @ptrCast(@constCast(tag));
    return c.b2CreateCircleShape(body.body_id, &shape_def,&circle);
}

pub const Box2dBody = struct {
    body_id: c.b2BodyId,
    pub fn init(world: Box2dWorld, body_def: c.b2BodyDef) Box2dBody {
        const body_id: c.b2BodyId = c.b2CreateBody(world.world_id, &body_def);
        return .{
            .body_id = body_id,
        };
    }

    pub fn init_old(world: c.b2WorldId, body_def: c.b2BodyDef) Box2dBody {
        const body_id: c.b2BodyId = c.b2CreateBody(world, &body_def);
        return .{
            .body_id = body_id,
        };
    }

    pub fn default_body_def() c.b2BodyDef {
        return c.b2DefaultBodyDef();
    }

    pub fn deinit(self: *Box2dBody) void {
        c.b2DestroyBody(self.body_id);
    }

    pub fn get_velocity(self: Box2dBody) rl.Vector2 {
        return vec2_b2dToRl(c.b2Body_GetLinearVelocity(self.body_id));
    }

    pub fn get_position(self: Box2dBody) rl.Vector2 {
        return vec2_b2dToRl(c.b2Body_GetPosition(self.body_id));
    }

    pub fn get_rotation(self: Box2dBody) f32 {
        return c.b2Rot_GetAngle(c.b2Body_GetRotation(self.body_id));
    }

    pub fn sleep(self: *Box2dBody) void {
        c.b2Body_Disable(self.body_id);
    }
};

pub const Box2dWorld = struct {
    world_id: c.b2WorldId,
    ball_body: Box2dBody,
    flipper_left: Box2dBody,
    flipper_right: Box2dBody,
    flipper_left_joint_id: c.b2JointId,
    flipper_right_joint_id: c.b2JointId,

    pub fn init(gravity: rl.Vector2) Box2dWorld {
        const gravity_dto: c.b2Vec2 = .{
            .x = gravity.x,
            .y = gravity.y,
        };
        var world_def: c.b2WorldDef = c.b2DefaultWorldDef();
        world_def.gravity = gravity_dto;
        const world_id: c.b2WorldId = c.b2CreateWorld(&world_def);

        // // static bodies
        const ground_body_def: c.b2BodyDef = c.b2DefaultBodyDef();

        const ground_body = Box2dBody.init_old(world_id, ground_body_def);
        {
            const GROUND_BODY_COUNT = 5;
            const vs: [GROUND_BODY_COUNT]c.b2Vec2 = .{
                .{
                    .x = -10.0,
                    .y = 3.0,
                },
                .{
                    .x = -10.0,
                    .y = 25.0,
                },
                .{
                    .x = 10.0,
                    .y = 25.0,
                },
                .{
                    .x = 10.0,
                    .y = 3.0,
                },
                .{
                    .x = 0,
                    .y = -2.0,
                },
            };

            var body_chain_def = c.b2DefaultChainDef();
            var materials: [1]c.b2SurfaceMaterial = .{c.b2DefaultSurfaceMaterial()};
            materials[0].restitution = 0.3;
            materials[0].friction = 0.1;
            body_chain_def.points = @ptrCast(&vs);
            body_chain_def.count = GROUND_BODY_COUNT;
            body_chain_def.isLoop = true;
            body_chain_def.materials = @ptrCast(&materials);
            body_chain_def.materialCount = materials.len;
            _ = c.b2CreateChain(ground_body.body_id, &body_chain_def);
        }



        var ball_body_def: c.b2BodyDef = c.b2DefaultBodyDef();
        ball_body_def.position = vec2_rlToB2d(.{
            .x = 0.5,
            .y = 0.0,
        });
        ball_body_def.linearVelocity = .{
            .x = 0,
            .y = 0,
        };

        ball_body_def.type = c.b2_dynamicBody;
        ball_body_def.isBullet = true;
        const ball_body: Box2dBody = Box2dBody.init_old(world_id, ball_body_def);
        {
            var ball_shape_def = c.b2DefaultShapeDef();
            ball_shape_def.enableContactEvents = true;
            const ball_circle: c.b2Circle = .{
                .radius = 1,
                .center = .{.x = 0, .y = 0},
            };
            ball_shape_def.density = 0.1;
            _ = c.b2CreateCircleShape(ball_body.body_id, &ball_shape_def, &ball_circle);
        }

        var flipper_body_def = c.b2DefaultBodyDef();
        flipper_body_def.type = c.b2_dynamicBody;
        flipper_body_def.enableSleep = false;
        flipper_body_def.sleepThreshold = 10000;
        flipper_body_def.isAwake = true;
        const flipper_shape_def = c.b2DefaultShapeDef();

        const left_position: c.b2Vec2 = .{
            .x = -2.0,
            .y = -1,
        };

        const right_position: c.b2Vec2 = .{
            .x = 2.0,
            .y = -1,
        };

        flipper_body_def.position = left_position;
        const flipper_left = Box2dBody.init_old(world_id, flipper_body_def);

        flipper_body_def.position = right_position;
        const flipper_right = Box2dBody.init_old(world_id, flipper_body_def);

        const flipper_box = c.b2MakeBox(1.75, 0.2);
        _ = c.b2CreatePolygonShape(flipper_left.body_id, &flipper_shape_def, &flipper_box);
        _ = c.b2CreatePolygonShape(flipper_right.body_id, &flipper_shape_def, &flipper_box);

        var flipper_joint_def = c.b2DefaultRevoluteJointDef();
        flipper_joint_def.bodyIdA = ground_body.body_id;
        flipper_joint_def.localAnchorB = c.b2Vec2_zero;
        flipper_joint_def.enableMotor = true;
        flipper_joint_def.maxMotorTorque = 1000.0;
        flipper_joint_def.enableLimit = true;

        flipper_joint_def.motorSpeed = 0;
        flipper_joint_def.localAnchorA = left_position;
        flipper_joint_def.bodyIdB = flipper_left.body_id;
        flipper_joint_def.lowerAngle = -20.0 * c.B2_PI / 180.0;
        flipper_joint_def.upperAngle = 20.0 * c.B2_PI / 180.0;
        const left_joint_id = c.b2CreateRevoluteJoint(world_id, &flipper_joint_def);

        flipper_joint_def.motorSpeed = 0;
        flipper_joint_def.localAnchorA = right_position;
        flipper_joint_def.bodyIdB = flipper_right.body_id;
        flipper_joint_def.lowerAngle = -20.0 * c.B2_PI / 180.0;
        flipper_joint_def.upperAngle = 20.0 * c.B2_PI / 180.0;
        const right_joint_id = c.b2CreateRevoluteJoint(world_id, &flipper_joint_def);

        return .{
            .world_id = world_id,
            .ball_body = ball_body,
            .flipper_left = flipper_left,
            .flipper_right = flipper_right,
            .flipper_left_joint_id = left_joint_id,
            .flipper_right_joint_id = right_joint_id,
        };
    }

    pub fn get_rotation_joint_left(self: *Box2dWorld) f32 {
        return c.b2RevoluteJoint_GetAngle(self.flipper_left_joint_id) * (180 / c.B2_PI) * -1;
    }
    pub fn get_rotation_joint_right(self: *Box2dWorld) f32 {
        return c.b2RevoluteJoint_GetAngle(self.flipper_right_joint_id) * (180 / c.B2_PI) * -1 - 180;
    }

    pub fn activate_left(self: *Box2dWorld) void {
        c.b2RevoluteJoint_SetMotorSpeed(self.flipper_left_joint_id, 80);
    }

    pub fn activate_right(self: *Box2dWorld) void {
        c.b2RevoluteJoint_SetMotorSpeed(self.flipper_right_joint_id, -80);
    }

    pub fn deactivate_left(self: *Box2dWorld) void {
        c.b2RevoluteJoint_SetMotorSpeed(self.flipper_left_joint_id, -10);
    }

    pub fn deactivate_right(self: *Box2dWorld) void {
        c.b2RevoluteJoint_SetMotorSpeed(self.flipper_right_joint_id, 10);
    }

    pub fn step(self: *Box2dWorld, timestep: f32, step_count: usize) void {
        c.b2World_Step(self.world_id, timestep, @intCast(step_count));
    }

    pub fn deinit(self: *Box2dWorld) void {
        c.b2DestroyWorld(self.world_id);
    }

    // hack to make thing work
    pub fn check_contact_events(self: *Box2dWorld) bool {
        const contactEvents: c.b2ContactEvents = c.b2World_GetContactEvents( self.world_id );
        for (0..@intCast(contactEvents.beginCount)) |i| {
            const event = contactEvents.beginEvents[i];
            const shape_a = event.shapeIdA;
            const shape_b = event.shapeIdB;
            const userdata_a: ?*Tag = @ptrCast(@alignCast(c.b2Shape_GetUserData(shape_a)));
            const userdata_b: ?*Tag = @ptrCast(@alignCast(c.b2Shape_GetUserData(shape_b)));

            if (userdata_a) |userdata| {
                switch (userdata.entity) {
                    inline else => |e| e.damage(),
                }
            }
            if (userdata_b) |userdata| {
                switch (userdata.entity) {
                    inline else => |e| e.damage(),
                }
            }
        }
        return false;
    }
};

