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
    ram: [4]reg,

    buffer: u4,
    io: u4,  // output only
    sync: u1,
    cm: u1,
    reset: bool,
    is_chip: bool,
    
    data: u4,
    char: u2,
    chip_num: u2,
    instr: u4,

    step: TIMING,

    pub fn init(chip_num: u2) !*Intel4002 {
        const i: *Intel4002 = try alloc.create(Intel4002);
        
        i.chip_num = chip_num;
        i.is_chip = false;

        return i;
    }

    fn interpret(self: *Intel4002) void {
        std.debug.print("RAM INTERPRET: {X}\n", .{self.instr});
        switch (self.instr) {
            0 => {
                self.ram[self.char].data[self.data] = self.buffer;
            },
            1 => {
                self.io = self.buffer;
            },
            4...7 => {
                self.ram[self.char].stat[self.instr - 4] = self.buffer;
            },
            8 => {
                // implement borrow
                self.buffer, _ = @subWithOverflow(self.buffer, self.ram[self.char].data[self.data]);
            },
            9 => {
                self.buffer = self.ram[self.char].data[self.data];
            },
            11 => {
                // implement carry
                self.buffer, _ = @addWithOverflow(self.buffer, self.ram[self.char].data[self.data]);
            },
            12...15 => {
                self.buffer = self.ram[self.char].stat[self.instr - 12];
            },
            else => {}
        }

        self.is_chip = false;
    }

    pub fn tick(self: *Intel4002) void {
        if (!Clock.p1 and !Clock.p2) return;

        if (self.reset) {
            self.zeroOut();
            return;
        }


        if (Clock.p2) {
            switch (self.step) {
                TIMING.M2 => {
                    if (self.cm == 1 and self.is_chip) {
                        std.debug.print("RAM HIT 3\n", .{});
                        self.instr = self.buffer;
                    }
                },
                TIMING.X2 => {
                    if (self.cm == 1) {
                        std.debug.print("RAM HIT\n", .{});
                        self.checkRAM(self.buffer);
                    } else if (self.is_chip) {
                        self.interpret();
                    }
                },
                TIMING.X3 => {
                    if (self.is_chip) {
                        std.debug.print("RAM HIT 2\n", .{});
                        self.setupRAM();
                    }
                },
                else => {}
            }
            incStep(&self.step);
        }
    }

    fn checkRAM(self: *Intel4002, num: u4) void {
        self.is_chip = self.chip_num == num >> 2;
        self.char = @truncate(num);
    }

    fn setupRAM(self: *Intel4002) void {
        self.data = self.buffer;
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
        self.instr = 0;
        self.step = TIMING.A1;
    }
};