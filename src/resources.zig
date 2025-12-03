const std = @import("std");
const rl = @import("raylib");

const ModelResourceError = error{
    NegativeRef,
    UnloadReferencedModel,
    NullReference,
};

const ModelList = std.StringArrayHashMapUnmanaged(rl.Model);

pub const ModelResource = struct {
    model_list: ModelList,

    pub fn init() ModelResource {
        return .{
            .model_list = ModelList.empty,
        };
    }

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
    var model_resource = ModelResource.init();
    defer model_resource.deinit(allocator);

    const model = try model_resource.load(allocator, "assets/models/kirby_pinballin.glb");
    try std.testing.expectEqual(2, model.meshCount);
}