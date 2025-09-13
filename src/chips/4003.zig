const std = @import("std");
const alloc = @import("../main.zig").alloc;

const Clock = @import("4801.zig");
const TIMING = @import("internals/enum.zig").TIMING;

pub const Intel4003 = struct {
    data_in: u1,
    data_out: u1,
    enable: u1,
    reg: u10,
    buffer: u10,
    prev_clock: u1,
    clock: u1,
    power_on: bool,

    pub fn init() !*Intel4003 {
        const i = try alloc.create(Intel4003);

        i.clock = 0;
        i.power_on = false;
        i.buffer = 0;

        return i;
    }

    pub fn tick(self: *Intel4003) void {
        if (!self.power_on and self.clock == 1) { self.power_on = true; self.reg = 0; }
        else if (self.clock == 1 and self.prev_clock == 0) self.shift();

        self.prev_clock = self.clock;
        self.buffer = if (self.enable == 1) self.reg else 0;
    }

    pub fn shift(self: *Intel4003) void {
        self.data_out = @truncate(self.reg & 1);
        self.reg >>= 1;
        self.reg += @as(u10, self.data_in) << 9;
    }
};
