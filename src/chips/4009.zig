const std = @import("std");
const alloc = @import("../main.zig").alloc;

const Clock = @import("4801.zig");
const TIMING = @import("internals/enum.zig").TIMING;

pub const Intel4009 = struct {
    // pins
    data: u8,
    buffer: u4,
    io: u4,
    cmrom: u1,
    sync: u1,

    // latches
    data_in_buf: u8,
    data_bus_buf: u4,
    io_control: u4,
    io_in: u4,
    io_out: u4,

    step: TIMING,


    pub fn init() !*Intel4009 {
        const i = try alloc.create(Intel4009);

        return i;
    }

    pub fn tick(self: *Intel4009) void {
        if (!Clock.p1 and !Clock.p2) return;

        if (Clock.p1) {
            switch (self.step) {
                TIMING.M1 => { self.data_in_buf = self.data; self.buffer = @truncate(self.data >> 4); },
                TIMING.M2 => self.buffer = @truncate(self.data >> 0),
            }
        } else if (Clock.p2) {
            switch (self.step) {
            }
        }
    }
};