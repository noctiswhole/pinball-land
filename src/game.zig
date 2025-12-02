const box2d = @import("box2d.zig");
const rl = @import("raylib");

const Pinball = struct {
    world: box2d.Box2dWorld,
    pub fn init() void {
        const world = box2d.Box2dWorld.init(.{.x = 0, .y = -10.0});
        return .{
            .world = world,
        };
    }
};



pub const Cappy = struct {
    body: box2d.Box2dBody,
    animation_current_frame: i32,
    animation_frame_count: i32,
    animation: rl.ModelAnimation,
    position: rl.Vector2,
    model: rl.Model,
    model_cap: rl.Model,
    health: i32,

    pub fn init(world: box2d.Box2dWorld, position: rl.Vector2, model_path: [:0]const u8, model_cap_path: [:0]const u8, tag: *box2d.Tag) !Cappy {
        var body_def = box2d.Box2dBody.default_body_def();
        body_def.position = box2d.vec2_rlToB2d(position);
        const body = box2d.Box2dBody.init(world, body_def);
        const model: rl.Model = try rl.loadModel(model_path);
        const model_cap: rl.Model = try rl.loadModel(model_cap_path);
        const animations: []rl.ModelAnimation = try rl.loadModelAnimations(model_path);
        _ = box2d.create_circle_shape(body, 1.5, 1.5, tag);
        return .{
            .animation = animations[0],
            .animation_frame_count = @intCast(animations[0].frameCount),
            .model = model,
            .model_cap = model_cap,
            .animation_current_frame = 0,
            .body = body,
            .position = body.get_position(),
            .health = 2,
        };
    }

    pub fn update(self: *Cappy) void {
        self.position = .{
            .x = self.body.get_position().x * box2d.B2D_TO_RL_RATIO,
            .y = self.body.get_position().y * box2d.B2D_TO_RL_RATIO,
        };

        self.animation_current_frame = @mod(self.animation_current_frame + 1, self.animation_frame_count);
        rl.updateModelAnimation(self.model, self.animation, self.animation_current_frame);
        rl.updateModelAnimation(self.model_cap, self.animation, self.animation_current_frame);
    }

    pub fn damage(self: *Cappy) void {
        self.health -= 1;
        if (self.health <= 0) {
            self.body.sleep();
        }
    }

    pub fn draw(self: Cappy) void {
        if (self.health > 0) {
            rl.drawModel(self.model, .{
                .x = self.position.x,
                .y = self.position.y-20,
                .z = 0,
            }, 25, .white);
            if (self.health == 2) {
                rl.drawModel(self.model_cap, .{
                    .x = self.position.x,
                    .y = self.position.y-20,
                    .z = 0,
                }, 25, .white);
            }
        }
    }
};