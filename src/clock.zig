const std = @import("std");

pub var p1: bool = false;
pub var p2: bool = false;
var lastP: u1 = 1;
pub var currTime: i128 = undefined;

pub fn tick() void {
    const now: i128 = std.time.nanoTimestamp();

    if (now - currTime >= 400) {
        if (lastP == 1) {
            p1 = true;
        } else {
            p2 = true;
        }
    }
}