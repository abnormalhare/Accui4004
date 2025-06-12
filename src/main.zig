const std = @import("std");
const alloc = @import("root.zig").alloc;
const zeys = @import("zeys");
const builtin = @import("builtin");
const romcopy = @import("romcopy.zig");

const Intel4001 = @import("4001.zig").Intel4001;
const Intel4002 = @import("4002.zig").Intel4002;
const Intel4003 = @import("4003.zig").Intel4003;
const Intel4004 = @import("4004.zig").Intel4004;
const Intel3205 = @import("3205.zig").Intel3205;

const Controller = @import("controller.zig").Controller;
const Display = @import("display.zig").Display;

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
    shift_regs: [2]*Intel4003,
    decoder: *Intel3205,
    controller: *Controller,
    display: *Display,
    r: u8 = 0,
    threadEnded: bool = true,
    threadEnded2: bool = true,
    isPressed: bool,

    step: u2,
    print_type: u1,
    just_flipped_print_type: bool,
    linux_key_buffer: [16]u8,

    fn print_controller_input(self: *Computer) void {
        if (builtin.target.os.tag == .windows) {
            self.print_controller_input_windows();
        }
    }

    fn print_controller_input_windows(self: *Computer) void {
        if (!self.isPressed) {
            if (zeys.isPressed(zeys.VK.VK_RIGHT)) {
                if (self.r != 0x1F) self.r += 1 else self.r = 0;
                self.isPressed = true;
            }
            if (zeys.isPressed(zeys.VK.VK_LEFT)) {
                if (self.r != 0) self.r -= 1 else self.r = 0x1F;
                self.isPressed = true;
            }
            if (zeys.isPressed(zeys.VK.VK_R)) {
                self.isPressed = true;
                self.print_type = ~self.print_type;
                self.just_flipped_print_type = true;
            }
        } else {
            if (!zeys.isPressed(zeys.VK.VK_RIGHT) and !zeys.isPressed(zeys.VK.VK_LEFT) and !zeys.isPressed(zeys.VK.VK_R)) {
                self.isPressed = false;
            }
        }

        self.threadEnded = true;
    }

    fn print_state(self: *Computer) !void {
        if (self.just_flipped_print_type) {
            self.just_flipped_print_type = false;
            std.debug.print("\x1B[H\x1B[2J", .{});
        }

        switch (self.print_type) {
            0 => try self.print_component_state(),
            1 => try self.print_display_state(),
        }
    }

    fn print_component_state(self: *Computer) !void {
        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        const gpa_alloc = gpa.allocator();
        
        var buf = try gpa_alloc.alloc(u8, 0);
        defer gpa_alloc.free(buf);

        buf = try std.fmt.allocPrint(gpa_alloc, "|| INSTR: 0x{X:0>2} || @ROM 0x{X:0>3}\n", .{
            self.cpu.instr,
            self.cpu.stack[0],
        });

        var time = @intFromEnum(self.cpu.step);
        if (Clock.p2) time, _ = @subWithOverflow(time, 1);
        buf = switch (self.step) {
            else => buf,
            2 => try std.fmt.allocPrint(gpa_alloc, "{s}> TIMING: {}\n", .{buf, @as(TIMING, @enumFromInt(time))}),
            3 => try std.fmt.allocPrint(gpa_alloc, "{s}> TIMING: {}, {s}\n", .{buf, @as(TIMING, @enumFromInt(time)), if (Clock.p1) "p1" else "p2"}),
        };

        buf = try std.fmt.allocPrint(gpa_alloc, "{s}> ACC: 0x{X:0>1}  C: {}\n> SHIFT REGS: 0 {b:0>10} | 1 {b:0>10}\nCONT: [{X} {b}]->{b}\n> DECODER: {any}\n> CM: {b:0>1} | {b:0>4}\n", .{ buf,
            self.cpu.acc,
            @intFromBool(self.cpu.carry),
            self.shift_regs[0].buffer,
            self.shift_regs[1].buffer,
            self.controller.timing,
            self.controller.clock,
            self.controller.out,
            self.decoder.out,
            self.cpu.cm,
            self.cpu.cmram,
        });
        buf = try std.fmt.allocPrint(gpa_alloc, "{s}> 0 IO: {b:0>4} | 1 IO: {b:0>4} | 2 IO: {b:0>4}\n> REGS:\n >", .{ buf,
            self.roms[0].io,
            self.roms[1].io,
            self.roms[2].io,
        });

        var i: u8 = 0;
        while (i < 16) {
            buf = try std.fmt.allocPrint(gpa_alloc, "{s} 0x{X:0>1}", .{buf, self.cpu.reg[i]});
            if ((i % 4) == 3 and i != 15) {
                buf = try std.fmt.allocPrint(gpa_alloc, "{s}\n >", .{buf});
            } else if (i == 15) {
                buf = try std.fmt.allocPrint(gpa_alloc, "{s}\n> RAM {X}: \n > ", .{buf, self.r});
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
                buf = try std.fmt.allocPrint(gpa_alloc, "{s}\n > ", .{buf});
            } else if (i == 15) {
                buf = try std.fmt.allocPrint(gpa_alloc, "{s}\n\n > ", .{buf});
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

    fn print_display_state(self: *Computer) !void {
        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        const gpa_alloc = gpa.allocator();
        
        var buf = try gpa_alloc.alloc(u8, 0);
        defer gpa_alloc.free(buf);

        buf = try std.fmt.allocPrint(gpa_alloc, "{s}/--------\\\n| I-4004 |\n|--------|\n", .{buf});

        for (&self.display.disp) |scanline| {
            buf = try std.fmt.allocPrint(gpa_alloc, "{s}|", .{buf});
            for (&scanline) |pixel| {
                buf = try std.fmt.allocPrint(gpa_alloc, "{s}{b}", .{buf, pixel});
            }
            buf = try std.fmt.allocPrint(gpa_alloc, "{s}|\n", .{buf});
        }
        buf = try std.fmt.allocPrint(gpa_alloc, "{s}\\--------/\n\n", .{buf});

        buf = try std.fmt.allocPrint(gpa_alloc, "{s}|| SCANLINE: {d} || SIG: {d}{d} ||\n", .{buf, self.display.scanline, self.display.prev_signal, self.display.signal});
        buf = try std.fmt.allocPrint(gpa_alloc, "{s}|| INSTR: 0x{X:0>2} || @ROM 0x{X:0>3}  ||\n", .{buf,
            self.cpu.instr,
            self.cpu.stack[0],
        });

        std.debug.print("\x1B[H", .{});
        std.debug.print("{s}", .{buf});

        self.threadEnded2 = true;
    }

    fn sync_motherboard(self: *Computer, t: u3, num: u4) void {
        var bus: u4 = undefined;
        const cmrom: u1 = self.cpu.cm;

        if (t == 0) { // cpu
            bus = self.cpu.buffer;
            self.decoder.in = @intCast(self.cpu.cmram >> 1);
        } else if (t == 1) { // roms
            bus = self.roms[num].buffer;
            if (num == 0) {
                self.controller.signal = @truncate((self.roms[0].io & 1) >> 0);
                self.shift_regs[0].data_in = @truncate((self.roms[0].io & 2) >> 1);
                self.shift_regs[0].enable  = @truncate((self.roms[0].io & 4) >> 2);
                self.shift_regs[0].clock   = @truncate((self.roms[0].io & 8) >> 3);
            }
            if (num == 2) {
                self.display.signal = @truncate((self.roms[2].io & 1) >> 0);
                self.shift_regs[1].data_in = @truncate((self.roms[2].io & 2) >> 1);
                self.shift_regs[1].enable  = @truncate((self.roms[2].io & 4) >> 2);
                self.shift_regs[1].clock   = @truncate((self.roms[2].io & 8) >> 3);
            }
        } else if (t == 2) { // rams
            bus = self.rams[num].buffer;
        } else if (t == 4) { // controller
            self.shift_regs[0].clock |= self.controller.clock;
            self.shift_regs[0].data_in = self.controller.out;
        } else if (t == 5) { // shift reg
            if (num == 0) {
                self.roms[1].io = @truncate(self.shift_regs[0].buffer);
            }
        } else if (t == 6) {
            self.display.io = @truncate(self.shift_regs[1].buffer);
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

    fn pause(self: *Computer) void {
        while (!zeys.isPressed(zeys.VK.VK_RETURN)) {}
        while (zeys.isPressed(zeys.VK.VK_RETURN)) {}

        _ = self;
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

        var i: u4 = 0;
        for (&self.shift_regs) |*sr| {
            sr.*.tick();
            self.sync_motherboard(1, i);
            i += 1;
        }
        self.sync_motherboard(5, 0);

        self.display.tick();
        self.sync_motherboard(6, 0);

        if (self.threadEnded) {
            self.threadEnded = false;
            const contThread: std.Thread = try std.Thread.spawn(.{}, print_controller_input, .{self});
            _ = contThread;
        }

        if (((self.step == 2 and Clock.p2) or (self.step == 3 and (Clock.p1 or Clock.p2))) and !self.cpu.reset) {
            try self.print_state();
            self.pause();
        } else if (Clock.p2 and self.cpu.step == TIMING.A1 and !self.cpu.reset) {
            if (self.threadEnded2) {
                self.threadEnded2 = false;
                const debugThread: std.Thread = try std.Thread.spawn(.{}, print_state, .{self});
                _ = debugThread;
            }

            if (self.step == 1) {
                self.pause();
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
        i = 0;
        while (i < self.shift_regs.len) {
            self.shift_regs[i] = try Intel4003.init();
            i += 1;
        }

        // DISPLAY INIT
        self.display = try Display.init();

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
        comp.step = @as(u2, @intFromBool(std.mem.eql(u8, run, "step")));
        comp.step += @as(u2, @intFromBool(std.mem.eql(u8, run, "small_step"))) * 2;
        comp.step += @as(u2, @intFromBool(std.mem.eql(u8, run, "tiny_step"))) * 3;
    } else {
        comp.step = 0;
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
