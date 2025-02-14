const Clock = @import("clock.zig");

pub const Intel4001 = struct {
    chip_num: u4,
    rom: [0x100]u8,
    is_chip: bool,

    buffer: u4,
    io: u4,
    clear: bool,
    sync: u1,
    cm: u1,
    address: u8,
    data: u4,
    step: u3,

    pub fn tick(self: *Intel4001) void {
        if (!Clock.p1 and !Clock.p2) return;

        if (Clock.p2) {
            switch (self.step) {
                0 => self.address = @intCast((self.buffer >> 0) % 16),
                1 => self.address = @intCast((self.buffer >> 4) % 16),
                2 => self.checkROM(self.buffer),
            }
        } else if (Clock.p1) {
            switch (self.step) {
                3 => self.getData(0),
                4 => self.getData(1),
            }
        }
    }

    fn checkROM(self: *Intel4001, num: u4) void {
        self.is_chip = !self.cm or (self.cm and self.chip_num == num);
    }

    fn getData(self: *Intel4001, offset: u8) void {
        if (!self.is_chip) return;

        self.buffer = self.rom[self.address + offset];
    }
};