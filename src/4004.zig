const Clock = @import("clock.zig");

pub const Intel4004 = struct {
    buffer: u4,
    accumulator: u4,
    temp: u4,
    instr: u8,
    carry: bool,
    stack_plex: u2,
    stack: [4]u12,
    reg_plex: [16]u4,
    step: u3,

    sync: u1,

    fn interpret(self: *Intel4004) void {
        self.instr;
    }

    pub fn tick(self: *Intel4004) void {
        if (!Clock.p1 and !Clock.p2) return;

        if (Clock.p1) {
            switch (self.step) {
                0 => self.buffer  = @intCast((self.stack[0] >> 0) % 16),
                1 => self.buffer += @intCast((self.stack[0] >> 4) % 16),
                2 => self.buffer += @intCast((self.stack[0] >> 8) % 16),
                // 3 and 4 are ROM enabled
                5...7 => self.interpret()
            }
        } else if (Clock.p2) {
            switch (self.step) {
                3 => self.instr = @as(u8, self.buffer) << 4,
                4 => self.instr = @as(u8, self.buffer) << 0,
            }
        }
    }
};

