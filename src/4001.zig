const std = @import("std");
const alloc = @import("root.zig").alloc;
const zeys = @import("zeys");

const Clock = @import("4801.zig");
const TIMING = @import("enum.zig").TIMING;
const incStep = @import("enum.zig").incStep;

pub const Intel4001 = struct {
    chip_num: u4,
    rom: [0x100]u8,
    is_chip: bool,
    is_io_chip: bool,

    buffer: u4,
    io: u4,
    exec: u4,
    cl: bool,
    sync: u1,
    cm: u1,
    reset: bool,

    address: u8,

    step: TIMING,

    pub fn init(chip_num: u4, rom: *const [0x100]u8) !*Intel4001 {
        const i = try alloc.create(Intel4001);

        i.chip_num = chip_num;
        i.rom = rom.*;
        i.is_chip = false;
        i.is_io_chip = false;

        return i;
    }

    fn interpret(self: *Intel4001) void {
        self.is_io_chip = false;

        if (self.exec == 0x2) {
            self.io = self.buffer;
        } else if (self.exec == 0xA) {
            self.buffer = self.io;
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
                else => {},
                TIMING.M1 => self.getData(0),
                TIMING.M2 => self.getData(1),
                TIMING.X2 => if (self.is_io_chip) self.interpret(),
            }
        } else if (Clock.p2) {
            switch (self.step) {
                else => {},
                TIMING.A1 => self.checkROM(self.buffer),
                TIMING.A2 => self.address = @as(u8, self.buffer) << 4,
                TIMING.A3 => self.address += @as(u8, self.buffer) << 0,
                TIMING.M2 => self.setExec(@truncate(self.buffer)),
                TIMING.X2 => if (self.cm == 1) self.checkIO(self.buffer),
            }
            incStep(&self.step);
        }
    }

    fn checkROM(self: *Intel4001, num: u4) void {
        self.is_chip = (self.chip_num == num);
    }

    fn checkIO(self: *Intel4001, num: u4) void {
        self.is_io_chip = (self.chip_num == num);
    }

    fn setExec(self: *Intel4001, num: u4) void {
        self.exec = num;
    }

    fn getData(self: *Intel4001, step: u8) void {
        if (!self.is_chip) return;

        if (step == 0) {
            self.buffer = @truncate(self.rom[@as(u32, self.address)] >> 4);
        } else {
            self.buffer = @truncate(self.rom[@as(u32, self.address)] >> 0);
        }
    }

    fn zeroOut(self: *Intel4001) void {
        self.buffer = 0;
        self.cl = false;
        self.sync = 0;
        self.cm = 0;
        self.address = 0;
        self.step = TIMING.A1;
        self.io = 0;
    }
    fn clear(self: *Intel4001) void {
        self.io = 0;
    }
};
