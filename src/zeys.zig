const std = @import("std");

pub const tty = undefined;

fn init() void {
    tty = try std.fs.cwd().openFile("/dev/tty", .{ .mode = .read_write });
}