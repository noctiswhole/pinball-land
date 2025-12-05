const box2d = @import("box2d.zig");
const rl = @import("raylib");
const resources = @import("resources.zig");
const ModelResource = resources.ModelResource;
const ShaderResource = resources.ShaderResource;
const std = @import("std");

pub const Entity = union(enum) {
    cappy: *Cappy,
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
    tag: box2d.Tag,

    pub fn create(
        allocator: std.mem.Allocator,
        model_resource: *ModelResource,
        shader_resource: *ShaderResource,
        world: box2d.Box2dWorld,
        position: rl.Vector2,
        model_path: [:0]const u8,
        model_cap_path: [:0]const u8
    ) !*Cappy {
        const cappy = try allocator.create(Cappy);
        var body_def = box2d.Box2dBody.default_body_def();
        body_def.position = .{
            .x = position.x,
            .y = position.y,
        };
        const body = box2d.Box2dBody.init(world, body_def);
        const model: rl.Model = try model_resource.load(allocator, model_path);
        const model_cap: rl.Model = try model_resource.load(allocator, model_cap_path);
        const animations: []rl.ModelAnimation = try rl.loadModelAnimations(model_path);
        const shader: rl.Shader = try shader_resource.load(allocator, "assets/shaders/cell.vs.glsl", "assets/shaders/cell.fs.glsl");
        for (0..@intCast(model.materialCount)) |i| {
            model.materials[i].shader = shader;
        }
        for (0..@intCast(model_cap.materialCount)) |i| {
            model_cap.materials[i].shader = shader;
        }
        cappy.* = .{
            .animation = animations[0],
            .animation_frame_count = @intCast(animations[0].frameCount),
            .model = model,
            .model_cap = model_cap,
            .animation_current_frame = 0,
            .body = body,
            .position = body.get_position(),
            .health = 2,
            .tag = box2d.Tag{
                .entity = .{
                    .cappy = cappy,
                },
            },
        };
        _ = box2d.create_circle_shape(body, 1.25, 1.25, &cappy.tag);
        return cappy;
    }

    pub fn destroy(self: *Cappy, allocator: std.mem.Allocator) void {
        self.body.deinit();
        allocator.destroy(self);
    }

    pub fn update(self: *Cappy) void {
        self.position = self.body.get_position();

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
                .y = self.position.y - 20,
                .z = 0,
            }, 20, .white);
            if (self.health == 2) {
                rl.drawModel(self.model_cap, .{
                    .x = self.position.x,
                    .y = self.position.y - 20,
                    .z = 0,
                }, 20, .white);
            }
        }
    }
};
