const alloc = @import("root.zig").alloc;

pub const Display = struct {
    prev_io: u4,
    io: u4,
    disp: [3 * 16]bool, // 6 x 8 display
    step: u4,

    pub fn init() !*Display {
        const d = try alloc.create(Display);

        d.prev_io = 0;
        d.io = 0;
        for (&d.disp) |*pixel| {
            pixel.* = false;
        }

        return d;
    }

    pub fn tick(self: *Display) void {
        if ((self.prev_io & 8) == (self.io & 8)) return;

        self.prev_io = self.io;
        const step: u8 = @intCast(self.step);
        self.disp[step * 3 + 0] = (self.io & 4) == 1;
        self.disp[step * 3 + 1] = (self.io & 2) == 2;
        self.disp[step * 3 + 2] = (self.io & 1) == 1;

        self.step, _ = @addWithOverflow(self.step, 1);
    }
};
