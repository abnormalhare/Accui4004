const std = @import("std");
const alloc = @import("root.zig").alloc;
const zeys = if (builtin.target.os.tag == .windows) @import("zeys") else @import("zeys.zig");
const builtin = @import("builtin");
const romcopy = @import("romcopy.zig");
const reader = std.io.getStdIn().reader();

const Intel4001 = @import("4001.zig").Intel4001;
const Intel4002 = @import("4002.zig").Intel4002;
const Intel4003 = @import("4003.zig").Intel4003;
const Intel4004 = @import("4004.zig").Intel4004;
const Intel3205 = @import("3205.zig").Intel3205;

const Controller = @import("controller.zig").Controller;
const Display = @import("display.zig").Display;

const TIMING = @import("enum.zig").TIMING;
const Clock = @import("4801.zig");

const ChipType = enum(u8) {
    CPU, ROM, RAM, 
    DECODER, CONTROLLER, SHIFT_REG, DISPLAY
};

pub const Motherboard = struct {
    // Simulation variables
    cpu: *Intel4004,
    roms: [32]*Intel4001,
    rams: [32]*Intel4002,
    shift_regs: [2]*Intel4003,
    decoder: *Intel3205,
    controller: *Controller,
    display: *Display,
    bank: u1,

    // meta-variables
    running: bool,
    r: u8 = 0,
    threadEnded: bool,
    threadEnded2: bool,
    contThread: ?std.Thread, // Add thread handles
    debugThread: ?std.Thread,
    isPressed: bool,
    step: u2,

    // linux variables
    tty_file: std.fs.File,

    fn get_controller_input(self: *Motherboard) void {
        if (builtin.target.os.tag == .windows) {
            _ = self.get_controller_input_windows();
        } else if (builtin.target.os.tag == .linux) {
            _ = self.get_controller_input_linux();
        }
        self.threadEnded = true;
    }

    fn get_controller_input_paused(self: *Motherboard) bool {
        if (builtin.target.os.tag == .windows) {
            return self.get_controller_input_windows();
        } else if (builtin.target.os.tag == .linux) {
            return self.get_controller_input_linux();
        } else {
            return false;
        }
    }

    fn get_controller_input_windows(self: *Motherboard) bool {
        if (!self.isPressed) {
            if (zeys.isPressed(zeys.VK.VK_RIGHT)) {
                if (self.r != 0x1F) self.r += 1 else self.r = 0;
                self.isPressed = true;
                return true;
            }
            if (zeys.isPressed(zeys.VK.VK_LEFT)) {
                if (self.r != 0) self.r -= 1 else self.r = 0x1F;
                self.isPressed = true;
                return true;
            }
        } else {
            if (!zeys.isPressed(zeys.VK.VK_RIGHT) and !zeys.isPressed(zeys.VK.VK_LEFT)) {
                self.isPressed = false;
            }
        }

        return false;
    }

    fn get_controller_input_linux(self: *Motherboard) bool {
        const linux = std.os.linux;
        const tty_fd = self.tty_file.handle;

        var old_settings: linux.termios = undefined;
        _ = linux.tcgetattr(tty_fd, &old_settings);

        var new_settings: linux.termios = old_settings;
        new_settings.lflag.ICANON = false;
        new_settings.lflag.ECHO = false;
        
        _ = linux.tcsetattr(tty_fd, linux.TCSA.NOW, &new_settings);

        var is_non_alphanum_key: bool = false;
        var is_non_alphanum_key2: bool = false;
        var did_have_non_alphanum_key: bool = false;
        while (true) {
            const key: u8 = reader.readByte() catch |err| switch (err) { else => break };

            if (is_non_alphanum_key2) {
                did_have_non_alphanum_key = true;
                if (!self.isPressed) {
                    if (key == 'C') { // right
                        if (self.r != 0x1F) self.r += 1 else self.r = 0;
                        self.isPressed = true;
                        return true;
                    }
                    if (key == 'D') {
                        if (self.r != 0) self.r -= 1 else self.r = 0x1F;
                        self.isPressed = true;
                        return true;
                    }
                }
            }

            if (is_non_alphanum_key) {
                is_non_alphanum_key2 = (key == '[');
            }

            is_non_alphanum_key = (key == 27);
        }
        if (!did_have_non_alphanum_key) {
            self.isPressed = false;
        }

        return false;
    }

    fn print_state(self: *Motherboard) !void {
        var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
        const gpa_alloc = gpa.allocator();
        defer {
            const deinit_status = gpa.deinit();
            if (deinit_status == .leak) {
                @panic("LEAK @ print_state");
            }
        }

        var list = std.ArrayList(u8).init(gpa_alloc);
        defer list.deinit();

        const writer = list.writer();
        try writer.print("-----------------------------------------------------------\n", .{});

        try writer.print("| INSTR: 0x{X:0>2} | @ROM 0x{X:0>4}    | STACK: 0x{X:0>3} 0x{X:0>3} 0x{X:0>3} | isPressed: {}\n", .{
            self.cpu.instr,
            @as(u16, self.cpu.stack[0]) + (@as(u16, self.bank) << 12),
            self.cpu.stack[1],
            self.cpu.stack[2],
            self.cpu.stack[3],
            self.isPressed
        });

        var time = @intFromEnum(self.cpu.step);
        if (Clock.p2) time, _ = @subWithOverflow(time, 1);

        const name: []const u8 = std.enums.tagName(TIMING, @enumFromInt(time)).?;
        switch (self.step) {
            else => {},
            2 => try writer.print("| TIMING: {s}  |                |                          |\n", .{name}),
            3 => try writer.print("| TIMING: {s}  | SUBCYCLE: {s}   |                          |\n", .{name, if (Clock.p1) "p1" else "p2"}),
        }

        try writer.print("|---------------------------------------------------------|-,----------,\n", .{});

        try writer.print("| REGS | ACC: 0x{X:0>1}  C: {b} | CONT: [{X} {b}]->{b} | CMROM: {b:0>1}       | |  I-4004  |\n", .{
            self.cpu.acc,
            @intFromBool(self.cpu.carry),
            self.controller.timing,
            self.controller.clock,
            self.controller.out,
            self.cpu.cm,
        });
        try writer.print("|-----------------------|----------------| CMRAM: {b:0>4}    | |----------|\n", .{
            self.cpu.cmram
        });

        try writer.print("| 0x{X:0>1} 0x{X:0>1} 0x{X:0>1} 0x{X:0>1}       |   SHIFT REGS   |----------------| | {b}{b}{b}{b}{b}{b}{b}{b} |\n", .{
            self.cpu.reg[0], self.cpu.reg[1], self.cpu.reg[2], self.cpu.reg[3],
            self.display.disp[0][0], self.display.disp[0][1], self.display.disp[0][2], self.display.disp[0][3],
            self.display.disp[0][4], self.display.disp[0][5], self.display.disp[0][6], self.display.disp[0][7]
        });

        try writer.print("| 0x{X:0>1} 0x{X:0>1} 0x{X:0>1} 0x{X:0>1}       | 0 {X:0>10}   |    DECODER     | | {b}{b}{b}{b}{b}{b}{b}{b} |\n", .{
            self.cpu.reg[4], self.cpu.reg[5], self.cpu.reg[6], self.cpu.reg[7], 
            self.shift_regs[0].buffer,
            self.display.disp[1][0], self.display.disp[1][1], self.display.disp[1][2], self.display.disp[1][3],
            self.display.disp[1][4], self.display.disp[1][5], self.display.disp[1][6], self.display.disp[1][7]
        });

        try writer.print("| 0x{X:0>1} 0x{X:0>1} 0x{X:0>1} 0x{X:0>1}       | 1 {X:0>10}   |    {b}{b}{b}{b}{b}{b}{b}{b}    | | {b}{b}{b}{b}{b}{b}{b}{b} |\n", .{
            self.cpu.reg[8], self.cpu.reg[9], self.cpu.reg[10], self.cpu.reg[11], 
            self.shift_regs[1].buffer,
            self.decoder.out[0], self.decoder.out[1], self.decoder.out[2], self.decoder.out[3], self.decoder.out[4], self.decoder.out[5], self.decoder.out[6], self.decoder.out[7],
            self.display.disp[2][0], self.display.disp[2][1], self.display.disp[2][2], self.display.disp[2][3],
            self.display.disp[2][4], self.display.disp[2][5], self.display.disp[2][6], self.display.disp[2][7]
        });

        try writer.print("| 0x{X:0>1} 0x{X:0>1} 0x{X:0>1} 0x{X:0>1}       |                |                | | {b}{b}{b}{b}{b}{b}{b}{b} |\n", .{
            self.cpu.reg[12], self.cpu.reg[13], self.cpu.reg[14], self.cpu.reg[15], 
            self.display.disp[3][0], self.display.disp[3][1], self.display.disp[3][2], self.display.disp[3][3],
            self.display.disp[3][4], self.display.disp[3][5], self.display.disp[3][6], self.display.disp[3][7]
        });

        try writer.print("|---------------------------------------------------------| | {b}{b}{b}{b}{b}{b}{b}{b} |\n", .{
            self.display.disp[4][0], self.display.disp[4][1], self.display.disp[4][2], self.display.disp[4][3],
            self.display.disp[4][4], self.display.disp[4][5], self.display.disp[4][6], self.display.disp[4][7]
        });

        try writer.print("| ROM IO          | RAM IO          | RAM[{X:0>2}]             | | {b}{b}{b}{b}{b}{b}{b}{b} |\n", .{
            self.r,
            self.display.disp[5][0], self.display.disp[5][1], self.display.disp[5][2], self.display.disp[5][3],
            self.display.disp[5][4], self.display.disp[5][5], self.display.disp[5][6], self.display.disp[5][7]
        });

        var i: u8 = 0;
        while (i < 4) {
            const ii: u8 = i * 4;
            try writer.print("| 0x{X:0>1} 0x{X:0>1} 0x{X:0>1} 0x{X:0>1} | 0x{X:0>1} 0x{X:0>1} 0x{X:0>1} 0x{X:0>1} | ", .{
                self.roms[ii + 0].io,
                self.roms[ii + 1].io,
                self.roms[ii + 2].io,
                self.roms[ii + 3].io,
                self.rams[ii + 0].io,
                self.rams[ii + 1].io,
                self.rams[ii + 2].io,
                self.rams[ii + 3].io,
            });
            var j: u8 = 0;
            while (j < 4) {
                try writer.print("{X:0>1}{X:0>1}{X:0>1}{X:0>1} ", .{
                    self.rams[self.r].ram[j].data[ii + 0],
                    self.rams[self.r].ram[j].data[ii + 1],
                    self.rams[self.r].ram[j].data[ii + 2],
                    self.rams[self.r].ram[j].data[ii + 3],
                });
                j += 1;
            }

            switch (i) {
                else => {},
                0 => {
                    try writer.print("| | {b}{b}{b}{b}{b}{b}{b}{b} ", .{
                        self.display.disp[6][0], self.display.disp[6][1], self.display.disp[6][2], self.display.disp[6][3],
                        self.display.disp[6][4], self.display.disp[6][5], self.display.disp[6][6], self.display.disp[6][7]
                    });
                },
                1 => {
                    try writer.print("| | {b}{b}{b}{b}{b}{b}{b}{b} ", .{
                        self.display.disp[7][0], self.display.disp[7][1], self.display.disp[7][2], self.display.disp[7][3],
                        self.display.disp[7][4], self.display.disp[7][5], self.display.disp[7][6], self.display.disp[7][7]
                    });
                },
                2 => {
                    try writer.print("|-'----------'\n", .{});
                }
            }

            if (i != 2)
                try writer.print("|\n", .{});

            i += 1;
        }

        try writer.print("-----------------------------------------------------------\n", .{});

        std.debug.print("\x1B[H", .{});
        std.debug.print("{s}", .{list.items});

        self.threadEnded2 = true;
    }

    // layout: 1 CPU, 32 ROM (banked), 32 RAM, 10-bit SR connected to ROM 0,
    //   Controller with input from ROM 0 and output to ROM 1
    // RAM connected via 3205 decoder of CM-RAM 1 to CM-RAM 3
    //
    // NOTE: when a chip needs to send data to another chip, place it in the
    // if statement of the chip send the data,
    // eg in .ROM:    `self.controller.signal = self.roms[0].io & 1`
    fn sync_motherboard(self: *Motherboard, chip_type: ChipType, num: u8) void {
        var bus: u4 = undefined;
        const cmrom: u1 = self.cpu.cm;

        if (chip_type == .CPU) {
            bus = self.cpu.buffer;
            // connects the decoder to the 3 MSB of cm-ram
            self.decoder.in = @intCast(self.cpu.cmram >> 1);
        } else if (chip_type == .ROM) {
            // virtual ROM is 13-bit, with 12 being the standard area and 1 bit that can be flipped for banking
            bus = self.roms[@as(u8, num) + (16 * @as(u8, self.bank))].buffer;
            if (num == 0) {
                // ROM 0 connects the controller output
                self.controller.signal =     @truncate((self.roms[0].io & 1) >> 0);
                self.shift_regs[0].data_in = @truncate((self.roms[0].io & 2) >> 1);
                self.shift_regs[0].enable  = @truncate((self.roms[0].io & 4) >> 2);
                self.shift_regs[0].clock   = @truncate((self.roms[0].io & 8) >> 3);
            }
            if (num == 2) {
                // ROM 2 connects the display
                self.display.signal =        @truncate((self.roms[2].io & 1) >> 0);
                self.shift_regs[1].data_in = @truncate((self.roms[2].io & 2) >> 1);
                self.shift_regs[1].enable  = @truncate((self.roms[2].io & 4) >> 2);
                self.shift_regs[1].clock   = @truncate((self.roms[2].io & 8) >> 3);
            }
        } else if (chip_type == .RAM) {
            bus = self.rams[num].buffer;
            if (num == 5) {
                // bit flip for banking
                self.bank = @truncate(self.rams[5].io);
            }
        } else if (chip_type == .CONTROLLER) {
            self.shift_regs[0].clock |= self.controller.clock;
            self.shift_regs[0].data_in = self.controller.out;
        } else if (chip_type == .SHIFT_REG) { // shift reg
            if (num == 1) {
                // ROM 1 controls the controller input
                self.roms[1].io = @truncate(self.shift_regs[0].buffer);
            }
        } else if (chip_type == .DISPLAY) {
            self.display.io = @truncate(self.shift_regs[1].buffer);
        }

        const chip_type_num: u8 = @intFromEnum(chip_type);
        const chip_is_bus_wired: bool = (chip_type_num < 3);

        // CPU
        self.cpu.buffer = if (chip_is_bus_wired) bus else self.cpu.buffer;

        // ROM
        for (&self.roms) |*rom| {
            rom.*.buffer = if (chip_is_bus_wired) bus else rom.*.buffer;
            rom.*.cm = cmrom;
        }

        // RAM
        for (&self.rams) |*ram| {
            ram.*.buffer = if (chip_is_bus_wired) bus else ram.*.buffer;
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

    fn pause(self: *Motherboard) !void {
        try self.print_state();

        while (!zeys.isPressed(zeys.VK.VK_RETURN)) {
            const toPrint: bool = self.get_controller_input_paused();
            if (toPrint) {
                try self.print_state();
            }
        }
        while (zeys.isPressed(zeys.VK.VK_RETURN)) {
            const toPrint: bool = self.get_controller_input_paused();
            if (toPrint) {
                try self.print_state();
            }
        }
    }

    fn check_threads(self: *Motherboard) !void {
        if (self.threadEnded) {
            self.threadEnded = false;
            if (self.contThread) |*t| {
                t.join();
                self.contThread = null;
            }
            self.contThread = try std.Thread.spawn(.{}, get_controller_input, .{self});
        }
        if (self.threadEnded2) {
            self.threadEnded2 = false;
            if (self.debugThread) |*t| {
                t.join();
                self.debugThread = null;
            }
            self.debugThread = try std.Thread.spawn(.{}, print_state, .{self});
        }
    }

    pub fn tick(self: *Motherboard) !void {
        self.cpu.tick();
        self.sync_motherboard(.CPU, 0);

        for (&self.roms) |*rom| {
            rom.*.tick();
            self.sync_motherboard(.ROM, rom.*.chip_num);
        }
        
        var chipset: u4 = 0;
        for (&self.rams) |*ram| {
            if (ram.*.chip_num == 0) chipset += 1;
            ram.*.tick();
            self.sync_motherboard(.RAM, @as(u8, ram.*.chip_num) + @as(u8, chipset - 1) * 4);
        }

        self.decoder.tick();
        self.sync_motherboard(.DECODER, 0);

        self.controller.tick();
        self.sync_motherboard(.CONTROLLER, 0);

        var i: u4 = 0;
        for (&self.shift_regs) |*sr| {
            sr.*.tick();
            self.sync_motherboard(.SHIFT_REG, i);
            i += 1;
        }
        self.sync_motherboard(.SHIFT_REG, 0);

        self.display.tick();
        self.sync_motherboard(.DISPLAY, 0);
        
        switch (self.step) {
            0 => if (Clock.p2 and self.cpu.step == TIMING.A1 and !self.cpu.reset) try self.check_threads(),
            1 => if (Clock.p2 and self.cpu.step == TIMING.A1 and !self.cpu.reset) try self.pause(),
            2 => if (self.step == 2 and Clock.p2 and !self.cpu.reset) try self.pause(),
            3 => if (self.step == 3 and (Clock.p1 or Clock.p2) and !self.cpu.reset) try self.pause()
        }

        Clock.p1 = false;
        Clock.p2 = false;
    }

    pub fn deinit(self: *Motherboard) void {
        if (self.contThread) |*t| {
            t.join();
            self.contThread = null;
        }
        if (self.debugThread) |*t| {
            t.join();
            self.debugThread = null;
        }
        self.tty_file.close();
    }

    pub fn linux_init(self: *Motherboard) !void {
        self.tty_file = try std.fs.openFileAbsolute("/dev/tty", .{});
    }

    pub fn init(filename: []u8) !*Motherboard {
        const self: *Motherboard = try alloc.create(Motherboard);

        self.running = true;

        // CPU INIT
        self.r = 0;
        self.cpu = try Intel4004.init();

        // ROM INIT
        var file = try std.fs.cwd().openFile(filename, .{});
        defer file.close();
        
        var checkStr: [3]u8 = .{ 0, 0, 0 };
        _ = try file.read(&checkStr);
        if (!std.mem.eql(u8, &checkStr, "i44")) {
            return error.NotI4004File;
        }
        try file.seekTo(0x10);

        var i: u8 = 0;
        while (i < 32) {
            const readROM: []u8 = try alloc.alloc(u8, 0x100);
            defer alloc.free(readROM);
            
            _ = try file.read(readROM);
            var rom: [0x100]u8 = undefined;
            romcopy.copyROM(&rom, readROM);
            self.roms[i] = try Intel4001.init(@truncate(i), &rom);
            i += 1;
        }

        // RAM INIT
        i = 0;
        while (i < self.rams.len) {
            self.rams[i] = try Intel4002.init(@truncate(i));
            i += 1;
        }
        self.bank = 0;

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

        // THREAD INIT
        self.contThread = null;
        self.debugThread = null;
        self.threadEnded = true;
        self.threadEnded2 = true;

        // DEBUG INIT
        self.step = 0;
        self.isPressed = false;

        if (builtin.target.os.tag == .linux) {
            try self.linux_init();
        }

        return self;
    }
};