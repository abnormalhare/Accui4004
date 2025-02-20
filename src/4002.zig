const std = @import("std");
const alloc = @import("root.zig").alloc;

const Clock = @import("clock.zig");
const TIMING = @import("enum.zig").TIMING;
const incStep = @import("enum.zig").incStep;

const reg = struct {
    data: [16]u4,
    stat: [4]u4,
};

pub const Intel4002 = struct {
    chip_num: u2,
    ram: [4]reg,
    is_chip: bool,

    buffer: u4,
    io: u4,  // output only
    sync: u1,
    cm: u1,
    reset: bool,

    step: TIMING,

    pub fn init(chip_num: u4) !*Intel4002 {
        const i: *Intel4002 = try alloc.create(Intel4002);
        
        i.chip_num = chip_num;
        i.is_chip = false;

        return i;
    }

    pub fn tick(self: *Intel4002) void {
        if (!Clock.p1 and !Clock.p2) return;

        if (self.reset) {
            self.zeroOut();
            return;
        }

        if (Clock.p1) {
            switch (self.step) {
                
            }
        } else if (Clock.p2) {
        }
    }

    fn zeroOut(self: *Intel4002) void {
        for (&self.ram) |*r| {
            for (&r.data) |*d| {
                d.* = 0;
            }
            for (&r.stat) |*s| {
                s.* = 0;
            }
        }
        self.buffer = 0;
        self.io = 0;
        self.sync = 0;
        self.cm = 0;
        self.reset = 0;
        self.step = TIMING.A1;
    }
};