const std = @import("std");
const ROM_SIZE = @import("root.zig").ROM_SIZE;

pub fn copyROM(dest: *[ROM_SIZE]u8, source: []u8) void {
    const s: []u8 = source;
    var i: u16 = 0;
    while (i < ROM_SIZE) {
        dest[i] = s[i];
        i += 1;
    }
}
