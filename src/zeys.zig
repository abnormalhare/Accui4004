const std = @import("std");

pub var tty: std.fs.File = undefined;

pub fn init() !void {
    tty = try std.fs.cwd().openFile("/dev/tty", .{ .mode = .read_write });
}

pub fn deinit() void {
    tty.close();
}