const std = @import("std");
const rl = @import("raylib");

const ModelResourceError = error{
    NegativeRef,
    UnloadReferencedModel,
    NullReference,
};
const ModelList = std.StringArrayHashMapUnmanaged(rl.Model);
const ShaderList = std.StringArrayHashMapUnmanaged(rl.Shader);
pub const shader_resource: ShaderResource = .{
    .shader_list = ShaderList.empty,
};
pub const model_resource: ModelResource = .{
    .model_list = ModelList.empty,
};

pub const ShaderResource = struct {
    shader_list: ShaderList,

    pub fn load(self: *ShaderResource, allocator: std.mem.Allocator, vs_shader_path: [:0]const u8, fs_shader_path: [:0]const u8) !rl.Shader {
        if (self.shader_list.get(fs_shader_path)) |shader| {
            return shader;
        } else {
            const shader = try rl.loadShader(vs_shader_path, fs_shader_path);
            try self.shader_list.put(allocator, fs_shader_path, shader);
            return self.shader_list.get(fs_shader_path).?;
        }
    }

    pub fn deinit(self: *ShaderResource, allocator: std.mem.Allocator) void {
        var it = self.shader_list.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.unload();
        }
        self.shader_list.deinit(allocator);
    }
};

pub const ModelResource = struct {
    model_list: ModelList,

    pub fn load(self: *ModelResource, allocator: std.mem.Allocator, model_path: [:0]const u8) !rl.Model {
        if (self.model_list.get(model_path)) |model| {
            return model;
        } else {
            const model = try rl.loadModel(model_path);
            try self.model_list.put(allocator, model_path, model);
            return self.model_list.get(model_path).?;
        }
    }

    pub fn deinit(self: *ModelResource, allocator: std.mem.Allocator) void {
        var it = self.model_list.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.unload();
        }
        self.model_list.deinit(allocator);
    }
};

test "model_load" {
    const testing = @import("testing.zig");
    testing.createWindow();
    try std.testing.expect(1 == 2);
    defer testing.destroyWindow();

    const allocator = std.testing.allocator;
    var model_resource_test = model_resource;
    defer model_resource_test.deinit(allocator);

    const model = try model_resource_test.load(allocator, "assets/models/kirby_pinballin.glb");
    try std.testing.expectEqual(2, model.meshCount);
}