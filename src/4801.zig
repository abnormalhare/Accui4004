const std = @import("std");

pub var p1: bool = false;
pub var p2: bool = false;
var lastP: u1 = 1;
pub var setTime: i128 = undefined;

pub fn tick() void {
    const now: i128 = std.time.nanoTimestamp();

    if (now - setTime >= 400) {
        if (lastP == 1) {
            p1 = true;
            lastP = 0;
        } else {
            p2 = true;
            lastP = 1;
        }
        setTime = now;
    }
}