const std = @import("std");
const alloc = @import("root.zig").alloc;

const Clock = @import("4801.zig");
const TIMING = @import("enum.zig").TIMING;

pub const Intel4009 = struct {
    // pins
    data: u8,
    buffer: u4,
    io: u4,
    cmrom: u1,

    // latches
    data_in_buf: u8,
    data_out_buf: u4,
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
            }
        } else if (Clock.p2) {
            switch (self.step) {
            }
        }
    }
};