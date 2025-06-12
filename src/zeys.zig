const std = @import("std");

pub const tty = undefined;

pub fn init() void {
    tty = try std.fs.cwd().openFile("/dev/tty", .{ .mode = .read_write });
}