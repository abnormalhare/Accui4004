const std = @import("std");
const alloc = @import("root.zig").alloc;
const zeys = @import("zeys");
const romcopy = @import("romcopy.zig");

const Intel4001 = @import("4001.zig").Intel4001;
const Intel4002 = @import("4002.zig").Intel4002;
const Intel4003 = @import("4003.zig").Intel4003;
const Intel4004 = @import("4004.zig").Intel4004;
const Intel3205 = @import("3205.zig").Intel3205;

const Controller = @import("controller.zig").Controller;

const TIMING = @import("enum.zig").TIMING;
const Clock = @import("4801.zig");

const Computer = struct {
    enable_state: u8,

    // layout: 1 CPU, 16 ROM, 32 RAM, 10-bit SR connected to ROM 0,
    //   Controller with input from ROM 0 and output to ROM 1
    // RAM connected via 3205 decoder of CM-RAM 1 to CM-RAM 3
    cpu: *Intel4004,
    roms: [16]*Intel4001,
    rams: [32]*Intel4002,
    shift_reg: *Intel4003,
    decoder: *Intel3205,
    controller: *Controller,
    r: u8 = 0,
    threadEnded: bool = true,
    threadEnded2: bool = true,
    isPressed: bool,

    step: bool,

    fn print_controller_input(self: *Computer) void {
        if (!self.isPressed) {
            if (zeys.isPressed(zeys.VK.VK_RIGHT)) {
                if (self.r != 0x1F) self.r += 1 else self.r = 0;
                self.isPressed = true;
            }
            if (zeys.isPressed(zeys.VK.VK_LEFT)) {
                if (self.r != 0) self.r -= 1 else self.r = 0x1F;
                self.isPressed = true;
            }
        } else {
            if (!zeys.isPressed(zeys.VK.VK_RIGHT) and !zeys.isPressed(zeys.VK.VK_LEFT)) {
                self.isPressed = false;
            }
        }

        self.threadEnded = true;
    }

    fn print_state(self: *Computer) !void {
        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        const gpa_alloc = gpa.allocator();
        
        var buf = try gpa_alloc.alloc(u8, 0);
        defer gpa_alloc.free(buf);

        buf = try std.fmt.allocPrint(gpa_alloc, "|| INSTR: 0x{X:0>2} || @ROM 0x{X:0>3}\n> ACC: 0x{X:0>1}  C: {}\n> SHIFT REG: {b:0>10} | CONT: {X}, {b}\n> DECODER: {any}\n> REGS:\n  >", .{
            self.cpu.instr,
            self.cpu.stack[0],
            self.cpu.acc,
            @intFromBool(self.cpu.carry),
            self.shift_reg.reg,
            self.controller.timing,
            self.controller.clock,
            self.decoder.out,
        });

        var i: u8 = 0;
        while (i < 16) {
            buf = try std.fmt.allocPrint(gpa_alloc, "{s} 0x{X:0>1}", .{buf, self.cpu.reg[i]});
            if ((i % 4) == 3 and i != 15) {
                buf = try std.fmt.allocPrint(gpa_alloc, "{s}\n  >", .{buf});
            } else if (i == 15) {
                buf = try std.fmt.allocPrint(gpa_alloc, "{s}\n RAM {X}: \n  > ", .{buf, self.r});
            }
            i += 1;
        }

        i = 0;
        while (i < 16) {
            const ii: u8 = i % 4;
            const v: u8 = (i / 4) * 4;
            buf = try std.fmt.allocPrint(gpa_alloc, "{s}{X:0>1}{X:0>1}{X:0>1}{X:0>1} ", .{ buf,
                self.rams[self.r].ram[ii].data[v], self.rams[self.r].ram[ii].data[v + 1], self.rams[self.r].ram[ii].data[v + 2], self.rams[self.r].ram[ii].data[v + 3]
            });

            if (i % 4 == 3 and i != 15) {
                buf = try std.fmt.allocPrint(gpa_alloc, "{s}\n  > ", .{buf});
            } else if (i == 15) {
                buf = try std.fmt.allocPrint(gpa_alloc, "{s}\n\n  > ", .{buf});
            }

            i += 1;
        }

        i = 0;
        while (i < 4) {
            buf = try std.fmt.allocPrint(gpa_alloc, "{s}{X:0>1}{X:0>1}{X:0>1}{X:0>1} ", .{ buf,
                self.rams[self.r].ram[i].stat[0], self.rams[self.r].ram[i].stat[1], self.rams[self.r].ram[i].stat[2], self.rams[self.r].ram[i].stat[3]
            });
            i += 1;
        }

        std.debug.print("\x1B[H", .{});
        std.debug.print("{s}", .{buf});

        self.threadEnded2 = true;
    }

    fn sync_motherboard(self: *Computer, t: u3, num: u4) void {
        var bus: u4 = 0;
        const cmrom: u1 = self.cpu.cm;

        if (t == 0) { // cpu
            bus = self.cpu.buffer;
            self.decoder.in = @intCast(self.cpu.cmram >> 1);
        } else if (t == 1) { // roms
            bus = self.roms[num].buffer;
            if (num == 0) {
                self.controller.signal = @truncate((self.roms[0].io & 1) >> 0);
                self.shift_reg.data_in = @truncate((self.roms[0].io & 2) >> 1);
                self.shift_reg.enable  = @truncate((self.roms[0].io & 4) >> 2);
                self.shift_reg.clock   = @truncate((self.roms[0].io & 8) >> 3);
            }
        } else if (t == 2) { // rams
            bus = self.rams[num].buffer;
        } else if (t == 4) { // controller
            self.shift_reg.clock |= self.controller.clock;
            self.shift_reg.data_in = self.controller.out;
        } else if (t == 5) { // shift reg
            self.roms[1].io = @truncate(self.shift_reg.buffer >> 7);
        }

        // CPU
        self.cpu.buffer = if (t < 3) bus else self.cpu.buffer;

        // ROM
        for (&self.roms) |*rom| {
            rom.*.buffer = if (t < 3) bus else rom.*.buffer;
            rom.*.cm = cmrom;
        }

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
        self.sync_motherboard(0, 0);

        for (&self.roms) |*rom| {
            rom.*.tick();
            self.sync_motherboard(1, rom.*.chip_num);
        }
        for (&self.rams) |*ram| {
            ram.*.tick();
            self.sync_motherboard(2, ram.*.chip_num);
        }

        self.decoder.tick();
        self.sync_motherboard(3, 0);

        self.controller.tick();
        self.sync_motherboard(4, 0);

        self.shift_reg.tick();
        self.sync_motherboard(5, 0);

        if (self.threadEnded) {
            self.threadEnded = false;
            const contThread: std.Thread = try std.Thread.spawn(.{}, print_controller_input, .{self});
            _ = contThread;
        }

        if (Clock.p2 and self.cpu.step == TIMING.A1 and !self.cpu.reset) {
            if (self.threadEnded2) {
                const debugThread: std.Thread = try std.Thread.spawn(.{}, print_state, .{self});
                self.threadEnded2 = false;
                _ = debugThread;
            }

            if (self.step) {
                while (!zeys.isPressed(zeys.VK.VK_RETURN)) {}
                while (zeys.isPressed(zeys.VK.VK_RETURN)) {}
            }
        }

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

        // SHIFT REG INIT
        self.shift_reg = try Intel4003.init();

        // DEBUG INIT
        self.threadEnded = true;
        self.threadEnded2 = true;
        self.isPressed = false;

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

    if (argsIterator.next()) |run| {
        comp.step = std.mem.eql(u8, run, "step");
    } else {
        comp.step = false;
    }

    std.debug.print("\x1B[H\x1B[2J", .{});

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
