const std = @import("std");

const Intel4004 = @import("4004.zig").Intel4004;
const TIMING = @import("enum.zig").TIMING;

const opfunc = *const fn (self: *Intel4004) void;

const conditional = struct {
    invert: bool,
    isAccZero: bool,
    isCarry: bool,
    isTest: bool,
};

/// NOP
fn OP_0x(self: *Intel4004) void {
    _ = self;
}

/// JCN
fn OP_1x(self: *Intel4004) void {
    if (self.step != TIMING.X1) return;

    if (self.prev_instr == 0) {
        self.prev_instr = self.instr;
        return;
    }

    const cond_int: u4 = @intCast(self.prev_instr & 0x0F);
    const conditions: conditional = .{
        .invert = (cond_int & 8) == 8,
        .isAccZero = (cond_int & 4) == 4,
        .isCarry = (cond_int & 2) == 2,
        .isTest = (cond_int & 1) == 1,
    };
    const jmp: u8 = self.instr;

    if (!conditions.invert) {
        if ((!conditions.isAccZero or (conditions.isAccZero and self.acc == 0)) and
            (!conditions.isCarry or (conditions.isCarry and self.carry)) and
            (!conditions.isTest or (conditions.isTest and !self.testP)))
        {
            self.stack[0] = (self.stack[0] & 0xF00) + @as(u12, jmp);
        }
    } else {
        if ((!conditions.isAccZero or (conditions.isAccZero and self.acc != 0)) and
            (!conditions.isCarry or (conditions.isCarry and !self.carry)) and
            (!conditions.isTest or (conditions.isTest and self.testP)))
        {
            self.stack[0] = (self.stack[0] & 0xF00) + @as(u12, jmp);
        }
    }

    self.prev_instr = 0;
}

fn OP_FIM(self: *Intel4004, reg: u4) void {
    if (self.step != TIMING.X1) return;

    if (self.prev_instr == 0) {
        self.prev_instr = self.instr;
        return;
    }

    self.reg[reg + 0] = @truncate(self.instr >> 4);
    self.reg[reg + 1] = @truncate(self.instr);

    self.prev_instr = 0;
}

fn OP_SRC(self: *Intel4004, reg: u4) void {
    switch (self.step) {
        TIMING.X2 => {
            self.cm = 1;
            self.cmram = self.bank;
            self.buffer = self.reg[reg + 0];
        },
        TIMING.X3 => self.buffer = self.reg[reg + 1],
        else => {},
    }

    self.prev_instr = 0;
}

/// FIM (even), SRC (odd)
fn OP_2x(self: *Intel4004) void {
    const amnt: u4 = if (self.prev_instr != 0) @truncate((self.prev_instr >> 1) << 1) else @truncate((self.instr >> 1) << 1);
    if ((self.prev_instr != 0 and self.prev_instr % 2 == 0) or self.instr % 2 == 0) {
        OP_FIM(self, amnt);
    } else {
        OP_SRC(self, amnt);
    }
}

var nextIsData: bool = false;
fn OP_FIN(self: *Intel4004, reg: u4) void {
    if (self.step != TIMING.X1) return;

    if (self.prev_instr == 0) {
        self.prev_instr = self.instr;

        self.stack[0] = (self.stack[0] & 0xF00) + (@as(u12, self.reg[0]) << 4) + @as(u12, self.reg[1]);
        return;
    }

    self.reg[reg + 0] = @intCast(self.instr >> 4);
    self.reg[reg + 1] = @truncate(self.instr);
}

fn OP_JIN(self: *Intel4004, reg: u4) void {
    if (self.step != TIMING.X1) return;

    const pc: u12 = self.stack[0];
    self.stack[0] = (pc & 0xF00) + (@as(u12, self.reg[reg]) << 4) + @as(u12, self.reg[reg + 1]);
}

/// FIN (even), JIN (odd)
fn OP_3x(self: *Intel4004) void {
    const amnt: u4 = if (self.prev_instr != 0) @truncate((self.prev_instr >> 1) << 1) else @truncate((self.instr >> 1) << 1);
    if ((self.prev_instr != 0 and self.prev_instr % 2 == 0) or self.instr % 2 == 0) {
        OP_FIN(self, amnt);
    } else {
        OP_JIN(self, amnt);
    }
}

// JUN
fn OP_4x(self: *Intel4004) void {
    if (self.step != TIMING.X1) return;

    if (self.prev_instr == 0) {
        self.prev_instr = self.instr;
        return;
    }

    self.stack[0] = (@as(u12, self.prev_instr & 0x0F) << 8) + @as(u12, self.instr);

    self.prev_instr = 0;
}

// JMS
fn OP_5x(self: *Intel4004) void {
    if (self.step != TIMING.X1) return;

    if (self.prev_instr == 0) {
        self.prev_instr = self.instr;
        return;
    }

    self.stack[3] = self.stack[2];
    self.stack[2] = self.stack[1];
    self.stack[1] = self.stack[0];

    self.stack[0] = (@as(u12, self.prev_instr & 0x0F) << 8) + @as(u12, self.instr);

    self.prev_instr = 0;
}

// INC
fn OP_6x(self: *Intel4004) void {
    if (self.step != TIMING.X1) return;

    var c: u1 = 0;

    self.reg[self.instr & 0x0F], c = @addWithOverflow(self.reg[self.instr & 0x0F], 1);
    self.carry = c == 1;
}

// ISZ
fn OP_7x(self: *Intel4004) void {
    if (self.step != TIMING.X1) return;

    if (self.prev_instr == 0) {
        self.prev_instr = self.instr;
        return;
    }

    var c: u1 = 0;
    self.reg[self.prev_instr & 0xF], c = @addWithOverflow(self.reg[self.prev_instr & 0xF], 1);
    self.carry = c == 1;

    if (self.reg[self.prev_instr & 0xF] != 0) {
        self.stack[0] = (self.stack[0] & 0xF00) + @as(u12, self.instr);
    }

    self.prev_instr = 0;
}

// ADD
fn OP_8x(self: *Intel4004) void {
    if (self.step != TIMING.X1) return;

    var c: u1 = 0;
    self.acc, c = @addWithOverflow(self.acc, self.reg[self.instr & 0x0F]);
    self.carry = c == 1;
}

// SUB
fn OP_9x(self: *Intel4004) void {
    if (self.step != TIMING.X1) return;

    const temp: u5, _ = @subWithOverflow(@as(u5, self.acc), @as(u5, self.reg[self.instr & 0x0F]));
    if (temp > 0xF)
        self.carry = false;
    self.acc, _ = @subWithOverflow(self.acc, self.reg[self.instr & 0x0F]);
}

// LD
fn OP_Ax(self: *Intel4004) void {
    if (self.step != TIMING.X1) return;

    self.acc = self.reg[self.instr & 0x0F];
}

// XCH
fn OP_Bx(self: *Intel4004) void {
    if (self.step != TIMING.X1) return;

    const temp = self.acc;
    self.acc = self.reg[self.instr & 0x0F];
    self.reg[self.instr & 0x0F] = temp;
}

// BBL
fn OP_Cx(self: *Intel4004) void {
    if (self.step != TIMING.X1) return;

    self.stack[0] = self.stack[1];
    self.stack[1] = self.stack[2];
    self.stack[2] = self.stack[3];

    self.acc = @truncate(self.instr);
}

// LDM
fn OP_Dx(self: *Intel4004) void {
    if (self.step != TIMING.X1) return;

    self.acc = @truncate(self.instr & 0xF);
}

/// Write/Read IO
fn OP_Ex(self: *Intel4004) void {
    switch (self.step) {
        else => {},
        TIMING.X2 => self.buffer = self.acc,
        TIMING.X3 => switch (self.instr & 0x0F) {
            // WR(M,R,0,1,2,3), WMP, WPM
            else => {},
            // RD(M,R,0,1,2,3)
            9...10, 12...15 => {
                self.acc = self.buffer;
            },
            // SBM
            8 => {
                var c: u1 = 0;
                self.acc, c = @subWithOverflow(self.acc, self.buffer);
                if (c == 1) {
                    self.carry = false;
                }
            },
            // ADM
            0xB => {
                var c: u1 = 0;
                self.acc, c = @addWithOverflow(self.acc, self.buffer);
                self.carry = c == 1;
            },
        },
    }
}

fn OP_Fx(self: *Intel4004) void {
    if (self.step != TIMING.X1) return;

    switch (self.instr & 0x0F) {
        // CLB
        0 => {
            self.carry = false;
            self.acc = 0;
        },
        // CLC
        1 => self.carry = false,
        // IAC
        2 => {
            var c: u1 = 0;
            self.acc, c = @addWithOverflow(self.acc, 1);
            self.carry = c == 1;
        },
        // CMC
        3 => self.carry = !self.carry,
        // CMA
        4 => self.acc = ~self.acc,
        // RAL
        5 => {
            const c: u4 = @intFromBool(self.carry);
            self.carry = ((self.acc >> 3) & 2) == 1;
            self.acc <<= 1;
            self.acc += c;
        },
        // RAR
        6 => {
            const c: u4 = @intFromBool(self.carry);
            self.carry = (self.acc & 2) == 1;
            self.acc >>= 1;
            self.acc += c << 3;
        },
        // TCC
        7 => {
            self.acc = @intFromBool(self.carry);
            self.carry = false;
        },
        // DAC
        8 => {
            var c: u1 = 0;
            self.acc, c = @subWithOverflow(self.acc, 1);
            if (c == 1) {
                self.carry = false;
            }
        },
        // TCS
        9 => {
            self.acc = 9 + @as(u4, @intFromBool(self.carry));
            self.carry = false;
        },
        // STC
        10 => self.carry = true,
        // DAA
        11 => {
            if (self.carry or self.acc > 9) {
                if (@as(u5, self.acc) + 6 >= 16) {
                    self.carry = true;
                }
                self.acc, _ = @addWithOverflow(self.acc, 6);
            }
        },
        // KBP
        12 => {
            if (self.acc <= 2) return else if (self.acc == 4) self.acc = 3 else if (self.acc == 8) self.acc = 4 else self.acc = 15;
        },
        // DCL
        13 => {
            switch (self.acc & 0x7) {
                0 => self.bank = 1,
                1 => self.bank = 2,
                2 => self.bank = 4,
                3 => self.bank = 6,
                4 => self.bank = 8,
                5 => self.bank = 10,
                6 => self.bank = 12,
                7 => self.bank = 14,
                else => {},
            }
        },
        else => {},
    }
}

pub const op_list: [16]opfunc = [_]opfunc{ OP_0x, OP_1x, OP_2x, OP_3x, OP_4x, OP_5x, OP_6x, OP_7x, OP_8x, OP_9x, OP_Ax, OP_Bx, OP_Cx, OP_Dx, OP_Ex, OP_Fx };
