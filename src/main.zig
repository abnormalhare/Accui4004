const std = @import("std");
const alloc = @import("root.zig").alloc;

const Intel4001 = @import("4001.zig").Intel4001;
const Intel4004 = @import("4004.zig").Intel4004;
const Clock = @import("clock.zig");

const Computer = struct {
    enable_state: u8,
    cpu: *Intel4004,
    roms: [16]*Intel4001,

    fn sync(self: *Computer, isCpu: bool, romNum: u4) void {
        var bus: u4 = 0;
        const cmrom: u1 = self.cpu.cm;
        
        if (isCpu) {
            bus = self.cpu.buffer;
        } else {
            bus = self.roms[romNum].buffer;
        }

        self.cpu.buffer = bus;
        for (&self.roms) |*rom| {
            rom.buffer = bus;
            rom.cm = cmrom;
        }
    }

    fn tick(self: *Computer) void {
        Clock.tick();
        self.cpu.tick();
        self.sync(true, 0);
        
        for (&self.roms) |*rom| {
            rom.tick();
        }

        Clock.p1 = false;
        Clock.p2 = false;
    }

    fn splitCopyROM(dest: [0x200 * 0x10]u4, source: [0x100 * 0x10]u8) void {
        var i: u8 = 0;
        while (i < 0x200) : (i += 1) {
            dest[i * 2 + 0] = @intCast(source[i]);
            dest[i * 2 + 1] = @intCast(source[i] >> 4);
        }
    }

    fn getROM(self: *Computer, filename: []const u8) !*u4 {
        var file = try std.fs.cwd().openFile(filename, .{});
        defer file.close();

        var str: [0x100 * 0x10]u8 = [_]u8{0} ** (0x100 * 0x10);
        const rom: [0x200 * 0x10]u4 = [_]u4{0} ** (0x200 * 0x10);
        var checkStr: [3]u8 = .{0, 0, 0};
        _ = try file.read(&checkStr);
        if (!std.mem.eql(u8, &checkStr, "i44")) { return error.NotI4004File; }

        try file.seekTo(0x10);
        _ = try file.read(&str);

        splitCopyROM(rom, str);

        _ = self;
        return rom;
    }

    fn copyROM(dest: [0x200]u4, source: *u4) void {
        var i: u8 = 0;
        while (i < 0x200) : (i += 1) {
            dest[i] = source.*;
            source += 1;
        }
    }

    pub fn init() !*Computer {
        const self: *Computer = try alloc.create(Computer);

        self.cpu = try Intel4004.init();

        var fileROM: *u4 = try self.getROM("input.i44");

        var i: u4 = 0;
        while (i < 16) : (i += 1) {
            const rom: [0x200]u4 = undefined;
            copyROM(rom, fileROM);
            self.roms[i] = try Intel4001.init(i, &rom);

            i += 1;
            fileROM = @ptrFromInt(@intFromPtr(fileROM) + 200);
        }

        return self;
    }
};

pub fn main() !void {
    // startup
    var comp: *Computer = try Computer.init();
    
    Clock.currTime = std.time.nanoTimestamp();

    // emulate
    var count: u8 = 0;
    comp.cpu.reset = true;
    while (true) {
        if (count >= 64) {
            comp.cpu.reset = false;
        }
        comp.tick();
        if (Clock.p2) count += 1;
    }
}