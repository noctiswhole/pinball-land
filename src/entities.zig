const game = @import("game.zig");

pub const Entity = union(enum) {
    cappy: *game.Cappy,
};