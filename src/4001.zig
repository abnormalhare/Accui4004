const std = @import("std");
const alloc = @import("root.zig").alloc;

const Clock = @import("clock.zig");
const TIMING = @import("enum.zig").TIMING;
const incStep = @import("enum.zig").incStep;

pub const Intel4001 = struct {
    chip_num: u4,
    rom: [0x200]u4,
    is_chip: bool,
    is_io_chip: bool,

    buffer: u4,
    io: u4,
    cl: bool,
    sync: u1,
    cm: u1,
    reset: bool,
    
    char: u2,
    
    step: TIMING,

    pub fn init(chip_num: u4, rom: *const [0x200]u4) !*Intel4001 {
        const i = try alloc.create(Intel4001);
        
        i.chip_num = chip_num;
        i.rom = rom.*;
        i.is_chip = false;

        return i;
    }

    fn interpret(self: *Intel4001) void {
        if (!self.is_io_chip) {
            self.is_io_chip = self.chip_num == self.buffer;
            if (self.is_io_chip)
            return;
        }
        
        const inst = self.rom[@as(u32, self.address) * 2 + 1];
        if (inst == 0x2 and Clock.p2) {
            self.io = self.buffer;
            self.is_io_chip = false;
        }

        if (inst == 0xA and Clock.p1) {
            self.buffer = self.io;
            self.is_io_chip = false;
        }

    }

    pub fn tick(self: *Intel4001) void {
        if (!Clock.p1 and !Clock.p2) return;

        if (self.reset) {
            self.zeroOut();
            return;
        }
        if (self.cl) self.clear();

        if (Clock.p1) {
            switch (self.step) {
                TIMING.M1 => self.getData(0),
                TIMING.M2 => self.getData(1),
                TIMING.X2 => {
                    if (self.is_io_chip) {
                        self.interpret();
                    }
                },
                else => {}
            }
        } else if (Clock.p2) {
            switch (self.step) {
                TIMING.A1 => self.checkROM(self.buffer),
                TIMING.A2 => self.address = @as(u8, self.buffer) << 4,
                TIMING.A3 => self.address = @as(u8, self.buffer) << 0,
                TIMING.X2 => {
                    if (self.cm == 1 or self.is_io_chip) {
                        self.interpret();
                    }
                },
                else => {}
            }
            incStep(&self.step);
        }

    }

    fn checkROM(self: *Intel4001, num: u4) void {
        self.is_chip = self.chip_num == num;
    }

    fn getData(self: *Intel4001, offset: u8) void {
        if (!self.is_chip) return;

        self.buffer = self.rom[@as(u32, self.address) * 2 + offset];
    }

    fn zeroOut(self: *Intel4001) void {
        self.buffer = 0;
        self.cl = false;
        self.sync = 0;
        self.cm = 0;
        self.address = 0;
        self.step = TIMING.A1;
    }
    fn clear(self: *Intel4001) void {
        self.io = 0;
    }
};