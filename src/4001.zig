const Clock = @import("clock.zig");

pub const Intel4001 = struct {
    chip_num: u4,
    rom: [0x200]u4,
    is_chip: bool,

    buffer: u4,
    io: u4,
    clear: bool,
    sync: u1,
    cm: u1,
    address: u8,
    data: u4,
    step: u3,
    instr: u2,

    pub fn tick(self: *Intel4001) void {
        if (!Clock.p1 and !Clock.p2) return;

        if (Clock.p2) {
            switch (self.step) {
                0 => self.address = @intCast(self.buffer),
                1 => self.address = @as(u8, self.buffer) << 4,
                2 => self.checkROM(self.buffer),
                else => {}
            }
        } else if (Clock.p1) {
            switch (self.step) {
                3 => self.getData(0),
                4 => self.getData(1),
                else => {}
            }
        }
        
        self.step += 1;
    }

    fn checkROM(self: *Intel4001, num: u4) void {
        self.is_chip = (self.cm == 0) or ((self.cm == 1) and self.chip_num == num);
    }

    fn getData(self: *Intel4001, offset: u8) void {
        if (!self.is_chip) return;

        self.buffer = self.rom[self.address + offset];
    }
};