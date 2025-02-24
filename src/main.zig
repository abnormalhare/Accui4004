const std = @import("std");
const alloc = @import("root.zig").alloc;
const zeys = @import("zeys");
const romcopy = @import("romcopy.zig");

const Intel4001 = @import("4001.zig").Intel4001;
const Intel4004 = @import("4004.zig").Intel4004;
const Intel4002 = @import("4002.zig").Intel4002;
const Intel3205 = @import("3205.zig").Intel3205;

const EmptyPort = @import("emptyport.zig").EmptyPort;
const Controller = @import("controller.zig").Controller;

const TIMING = @import("enum.zig").TIMING;
const Clock = @import("clock.zig");

const Computer = struct {
    enable_state: u8,
    cpu: *Intel4004,
    roms: [16]*Intel4001,
    rams: [32]*Intel4002,
    controller: *Controller,
    decoder: *Intel3205,
    r: u5 = 0,

    fn print_state(self: *Computer) !void {
        if (zeys.isPressed(zeys.VK.VK_LEFT)) {
            self.r, _ = @subWithOverflow(self.r, 1);
        } else if (zeys.isPressed(zeys.VK.VK_RIGHT)) {
            self.r, _ = @addWithOverflow(self.r, 1);
        }
        while (zeys.isPressed(zeys.VK.VK_LEFT) or zeys.isPressed(zeys.VK.VK_RIGHT)) {}

        std.debug.print("\x1B[H", .{});
        std.debug.print("|| INSTR: 0x{X:0>2} || @ROM 0x{X:0>3}\n> ACC: 0x{X:0>1}  C: {}\n> CONT: {X}\n> DECODER: {any}\n", .{
            self.cpu.instr,
            self.cpu.stack[0],
            self.cpu.acc,
            @intFromBool(self.cpu.carry),
            self.controller.io,
            self.decoder.out,
        });

        std.debug.print("> REGS:\n  > 0x{X:0>1} 0x{X:0>1} 0x{X:0>1} 0x{X:0>1}\n  > 0x{X:0>1} 0x{X:0>1} 0x{X:0>1} 0x{X:0>1}\n  > 0x{X:0>1} 0x{X:0>1} 0x{X:0>1} 0x{X:0>1}\n  > 0x{X:0>1} 0x{X:0>1} 0x{X:0>1} 0x{X:0>1}\n", .{
            self.cpu.reg[0],
            self.cpu.reg[1],
            self.cpu.reg[2],
            self.cpu.reg[3],
            self.cpu.reg[4],
            self.cpu.reg[5],
            self.cpu.reg[6],
            self.cpu.reg[7],
            self.cpu.reg[8],
            self.cpu.reg[9],
            self.cpu.reg[10],
            self.cpu.reg[11],
            self.cpu.reg[12],
            self.cpu.reg[13],
            self.cpu.reg[14],
            self.cpu.reg[15],
        });

        std.debug.print("> RAM {X}: \n  > {X:0>1}{X:0>1}{X:0>1}{X:0>1} {X:0>1}{X:0>1}{X:0>1}{X:0>1} {X:0>1}{X:0>1}{X:0>1}{X:0>1} {X:0>1}{X:0>1}{X:0>1}{X:0>1}\n", .{
            self.r,
            self.rams[self.r].ram[0].data[0],
            self.rams[self.r].ram[0].data[1],
            self.rams[self.r].ram[0].data[2],
            self.rams[self.r].ram[0].data[3],
            self.rams[self.r].ram[1].data[0],
            self.rams[self.r].ram[1].data[1],
            self.rams[self.r].ram[1].data[2],
            self.rams[self.r].ram[1].data[3],
            self.rams[self.r].ram[2].data[0],
            self.rams[self.r].ram[2].data[1],
            self.rams[self.r].ram[2].data[2],
            self.rams[self.r].ram[2].data[3],
            self.rams[self.r].ram[3].data[0],
            self.rams[self.r].ram[3].data[1],
            self.rams[self.r].ram[3].data[2],
            self.rams[self.r].ram[3].data[3],
        });
        std.debug.print("  > {X:0>1}{X:0>1}{X:0>1}{X:0>1} {X:0>1}{X:0>1}{X:0>1}{X:0>1} {X:0>1}{X:0>1}{X:0>1}{X:0>1} {X:0>1}{X:0>1}{X:0>1}{X:0>1}\n", .{
            self.rams[self.r].ram[0].data[4],
            self.rams[self.r].ram[0].data[5],
            self.rams[self.r].ram[0].data[6],
            self.rams[self.r].ram[0].data[7],
            self.rams[self.r].ram[1].data[4],
            self.rams[self.r].ram[1].data[5],
            self.rams[self.r].ram[1].data[6],
            self.rams[self.r].ram[1].data[7],
            self.rams[self.r].ram[2].data[4],
            self.rams[self.r].ram[2].data[5],
            self.rams[self.r].ram[2].data[6],
            self.rams[self.r].ram[2].data[7],
            self.rams[self.r].ram[3].data[4],
            self.rams[self.r].ram[3].data[5],
            self.rams[self.r].ram[3].data[6],
            self.rams[self.r].ram[3].data[7],
        });
        std.debug.print("  > {X:0>1}{X:0>1}{X:0>1}{X:0>1} {X:0>1}{X:0>1}{X:0>1}{X:0>1} {X:0>1}{X:0>1}{X:0>1}{X:0>1} {X:0>1}{X:0>1}{X:0>1}{X:0>1}\n", .{
            self.rams[self.r].ram[0].data[8],
            self.rams[self.r].ram[0].data[9],
            self.rams[self.r].ram[0].data[10],
            self.rams[self.r].ram[0].data[11],
            self.rams[self.r].ram[1].data[8],
            self.rams[self.r].ram[1].data[9],
            self.rams[self.r].ram[1].data[10],
            self.rams[self.r].ram[1].data[11],
            self.rams[self.r].ram[2].data[8],
            self.rams[self.r].ram[2].data[9],
            self.rams[self.r].ram[2].data[10],
            self.rams[self.r].ram[2].data[11],
            self.rams[self.r].ram[3].data[8],
            self.rams[self.r].ram[3].data[9],
            self.rams[self.r].ram[3].data[10],
            self.rams[self.r].ram[3].data[11],
        });
        std.debug.print("  > {X:0>1}{X:0>1}{X:0>1}{X:0>1} {X:0>1}{X:0>1}{X:0>1}{X:0>1} {X:0>1}{X:0>1}{X:0>1}{X:0>1} {X:0>1}{X:0>1}{X:0>1}{X:0>1}\n\n", .{
            self.rams[self.r].ram[0].data[12],
            self.rams[self.r].ram[0].data[13],
            self.rams[self.r].ram[0].data[14],
            self.rams[self.r].ram[0].data[15],
            self.rams[self.r].ram[1].data[12],
            self.rams[self.r].ram[1].data[13],
            self.rams[self.r].ram[1].data[14],
            self.rams[self.r].ram[1].data[15],
            self.rams[self.r].ram[2].data[12],
            self.rams[self.r].ram[2].data[13],
            self.rams[self.r].ram[2].data[14],
            self.rams[self.r].ram[2].data[15],
            self.rams[self.r].ram[3].data[12],
            self.rams[self.r].ram[3].data[13],
            self.rams[self.r].ram[3].data[14],
            self.rams[self.r].ram[3].data[15],
        });
        std.debug.print("  > {X:0>1}{X:0>1}{X:0>1}{X:0>1} {X:0>1}{X:0>1}{X:0>1}{X:0>1} {X:0>1}{X:0>1}{X:0>1}{X:0>1} {X:0>1}{X:0>1}{X:0>1}{X:0>1}\n", .{
            self.rams[self.r].ram[0].stat[0],
            self.rams[self.r].ram[0].stat[1],
            self.rams[self.r].ram[0].stat[2],
            self.rams[self.r].ram[0].stat[3],
            self.rams[self.r].ram[1].stat[0],
            self.rams[self.r].ram[1].stat[1],
            self.rams[self.r].ram[1].stat[2],
            self.rams[self.r].ram[1].stat[3],
            self.rams[self.r].ram[2].stat[0],
            self.rams[self.r].ram[2].stat[1],
            self.rams[self.r].ram[2].stat[2],
            self.rams[self.r].ram[2].stat[3],
            self.rams[self.r].ram[3].stat[0],
            self.rams[self.r].ram[3].stat[1],
            self.rams[self.r].ram[3].stat[2],
            self.rams[self.r].ram[3].stat[3],
        });
    }

    // this emulates the motherboard
    // layout: 1 CPU, 16 ROM, 16 RAM, Controller connected to ROM 0
    // RAM connected via 3205 decoder of CM-RAM 1 to CM-RAM 3
    fn sync(self: *Computer, t: u3, num: u4) void {
        var bus: u4 = 0;
        const cmrom: u1 = self.cpu.cm;

        if (t == 0) { // cpu
            bus = self.cpu.buffer;
            self.decoder.in = @intCast(self.cpu.cmram >> 1);
        } else if (t == 1) { // roms
            bus = self.roms[num].buffer;
            if (num == 0) {
                self.controller.io = self.roms[0].io;
            }
        } else if (t == 2) { // rams
            bus = self.rams[num].buffer;
        } else if (t == 3) { // controller
            self.roms[0].io = self.controller.io;
        }

        // CPU
        self.cpu.buffer = if (t < 3) bus else self.cpu.buffer;

        // ROM
        for (&self.roms) |*rom| {
            rom.*.buffer = if (t < 3) bus else rom.*.buffer;
            rom.*.cm = cmrom;
        }
        self.roms[0].io = self.controller.io;

        // RAM
        for (&self.rams) |*ram| {
            ram.*.buffer = if (t < 3) bus else ram.*.buffer;
        }

        // Decoder
        for (self.rams[0x0..0x4]) |*ram| {
            ram.*.cm = @truncate(self.cpu.cmram & 1);
        }
        var i: u8 = 4;
        while (i < 32) {
            for (self.rams[i..(i + 4)]) |*ram| {
                ram.*.cm = self.decoder.out[@divFloor(i, 4)];
            }
            i += 4;
        }

        if (self.cpu.sync == 1 and self.cpu.step == TIMING.A1) {
            for (&self.roms) |*rom| {
                rom.*.step = TIMING.X3;
            }
            for (&self.rams) |*ram| {
                ram.*.step = TIMING.X3;
            }
            self.cpu.sync = 0;
        }
    }

    fn tick(self: *Computer) !void {
        self.cpu.tick();
        self.sync(0, 0);

        for (&self.roms) |*rom| {
            rom.*.tick();
            self.sync(1, rom.*.chip_num);
        }
        for (&self.rams) |*ram| {
            ram.*.tick();
            self.sync(2, ram.*.chip_num);
        }

        self.decoder.tick();
        self.sync(4, 0);

        self.controller.tick();
        self.sync(3, 0);

        if (Clock.p2 and self.cpu.step == TIMING.A1 and !self.cpu.reset) try self.print_state();

        Clock.p1 = false;
        Clock.p2 = false;
    }

    pub fn init(filename: []u8) !*Computer {
        const self: *Computer = try alloc.create(Computer);

        // CPU INIT
        self.r = 0;
        self.cpu = try Intel4004.init();

        // ROM INIT
        var fileROM: *u4 = try romcopy.getROM(filename);
        var i: u8 = 0;
        while (i < 16) {
            var rom: [0x200]u4 = undefined;
            romcopy.copyROM(&rom, fileROM);
            self.roms[i] = try Intel4001.init(@intCast(i), &rom);
            i += 1;
            fileROM = @ptrFromInt(@intFromPtr(fileROM) + 0x200);
        }

        // RAM INIT
        i = 0;
        while (i < self.rams.len) {
            self.rams[i] = try Intel4002.init(@truncate(i));
            i += 1;
        }

        // DECODER INIT
        self.decoder = try Intel3205.init();

        // CONTROLLER INIT
        self.controller = try Controller.init();

        return self;
    }
};

pub fn main() !void {
    var filename: []u8 = undefined;
    // startup
    var argsIterator = try std.process.ArgIterator.initWithAllocator(alloc);
    defer argsIterator.deinit();

    _ = argsIterator.next();
    if (argsIterator.next()) |path| {
        filename = try alloc.alloc(u8, path.len);
        @memcpy(filename, path);
    } else {
        std.debug.print("Command Usage: [emu].exe [filename].i44", .{});
        return;
    }

    var comp: *Computer = try Computer.init(filename);
    Clock.setTime = std.time.nanoTimestamp();

    // std.debug.print("\x1B[H\x1B[2J", .{});

    // emulate
    var count: u32 = 0;
    comp.cpu.reset = true;
    for (&comp.roms) |*rom| {
        rom.*.reset = true;
    }
    for (&comp.rams) |*ram| {
        ram.*.reset = true;
    }
    while (true) {
        Clock.tick();
        if (Clock.p2) {
            count += 1;
        }
        try comp.tick();
        if (count == 64) {
            comp.cpu.reset = false;
            for (&comp.roms) |*rom| {
                rom.*.reset = false;
            }
            for (&comp.rams) |*ram| {
                ram.*.reset = false;
            }
        }
    }
}
