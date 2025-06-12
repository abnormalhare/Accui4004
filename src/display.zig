const std = @import("std");
const alloc = @import("root.zig").alloc;

pub const Display = struct {
    io: u8,
    disp: [8][8]u1, // 8 x 8 display
    scanline: u3,
    prev_signal: u1,
    signal: u1,

    pub fn init() !*Display {
        const d = try alloc.create(Display);

        d.io = 0;
        d.scanline = 0;
        d.signal = 0;
        for (&d.disp) |*scanline| {
            for (&scanline.*) |*pixel| {
                pixel.* = 0;
            }
        }

        return d;
    }

    pub fn tick(self: *Display) void {
        if (self.signal == 0 or self.prev_signal == 1) {
            self.prev_signal = self.signal;
            return;
        }

        self.prev_signal = self.signal;

        var i: u16 = 0;
        var temp_io: u8 = self.io;
        while (i < 8) {
            self.disp[self.scanline][i] = @truncate(temp_io);
            temp_io >>= 1;
            i += 1;
        }

        self.scanline, _ = @addWithOverflow(self.scanline, 1);
    }
};
