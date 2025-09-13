const std = @import("std");
const alloc = @import("../main.zig").alloc;

const Clock = @import("4801.zig");
const TIMING = @import("internals/enum.zig").TIMING;

pub const Intel4008 = struct {
    // pins
    buffer: u4,
    addr: u8,
    port: u4,
    cmrom: u1,
    sync: u1,

    // latch/mpx
    addr_mpx: u8,
    io_addr_mpx: u8,
    src_addr_mpx: u8,
    port_mpx: u4,

    step: TIMING,

    pub fn init() !*Intel4008 {
        const i = try alloc.create(Intel4008);

        return i;
    }

    pub fn tick(self: *Intel4008) void {
        if (!Clock.p1 and !Clock.p2) return;

        if (Clock.p1) {
            switch (self.step) {
                else => {},
                TIMING.M1 => { self.addr = self.addr_mpx; self.port = self.port_mpx; },
            }
        } else if (Clock.p2) {
            switch (self.step) {
                TIMING.A1 => self.addr_mpx = self.buffer,
                TIMING.A2 => self.addr_mpx += (self.buffer << 4),
                TIMING.A3 => { self.port_mpx = self.buffer; self.addr = self.addr_mpx; self.port = self.port_mpx; },
                TIMING.X2 => if (self.cmrom) { self.src_addr_mpx = self.buffer; },
                TIMING.X3 => if (self.cmrom) { self.src_addr_mpx += @as(u8, self.buffer) << 4; },
            }
        }
    }
};