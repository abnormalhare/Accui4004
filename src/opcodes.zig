const std = @import("std");
const zeys = @import("zeys");

const Intel4004 = @import("4004.zig").Intel4004;
const TIMING = @import("enum.zig").TIMING;

const opfunc = *const fn(self: *Intel4004) void;

const conditional = struct {
    invert: bool,
    isAccZero: bool,
    isCarry: bool,
    isTest: bool,
};

// NOP
fn OP_0x(self: *Intel4004) void {
    _ = self;
}

// JCN
fn OP_1x(self: *Intel4004) void {
    if (self.step != TIMING.X1) return;
    
    if (self.prev_instr == 0) {
        self.prev_instr = self.instr;
        return;
    }

    const cond_int: u4 = @intCast(self.prev_instr & 0x0F);
    const conditions: conditional = .{
        .invert    = (cond_int & 1) == 1,
        .isAccZero = (cond_int & 2) == 1,
        .isCarry   = (cond_int & 4) == 1,
        .isTest    = (cond_int & 8) == 1,
    };
    const jmp: u4 = @intCast((self.prev_instr & 0xF0) >> 4);

    if (!conditions.invert) {
        if (
            (!conditions.isAccZero or (conditions.isAccZero and self.acc == 0)) and
            (!conditions.isCarry   or (conditions.isCarry   and self.carry           )) and
            (!conditions.isTest    or (conditions.isTest    and self.testP           ))
        ) {
            self.stack[0] = jmp;
        }
    } else {
        if (
            (!conditions.isAccZero or (conditions.isAccZero and self.acc != 0)) and
            (!conditions.isCarry   or (conditions.isCarry   and !self.carry          )) and
            (!conditions.isTest    or (conditions.isTest    and !self.testP          ))
        ) {
            self.stack[0] = jmp;
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

// unimplemented I/O functionality
fn OP_SRC(self: *Intel4004, reg: u4) void {
    switch (self.step) {
        TIMING.X2 => {
            self.cm = 1;
            self.buffer = self.reg[reg + 0];
        },
        TIMING.X3 => self.buffer = self.reg[reg + 1],
        else => {}
    }
}

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
    self.reg[reg + 1] = @intCast(self.instr >> 0);
}

fn OP_JIN(self: *Intel4004, reg: u4) void {
    if (self.step != TIMING.X1) return;

    const pc: u12 = self.stack[0];
    self.stack[0] = (pc & 0xF00) + (@as(u12, self.reg[reg]) << 4) + @as(u12, self.reg[reg + 1]);
}

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

    self.reg[self.instr & 0x0F] += 1;
}

// ISZ
fn OP_7x(self: *Intel4004) void {
    if (self.step != TIMING.X1) return;

    if (self.prev_instr == 0) {
        self.prev_instr = self.instr;
        return;
    }

    self.reg[self.prev_instr & 0xF] += 1;

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

    if (@as(u5, self.acc) - @as(u5, self.reg[self.instr & 0x0F]) > 0xF)
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

    self.acc = @intCast(self.instr);
}

// LDM
fn OP_Dx(self: *Intel4004) void {
    if (self.step != TIMING.X1) return;

    self.acc = @intCast(self.instr);
}

fn OP_Ex(self: *Intel4004) void {
    if (self.step != TIMING.X2) return;
    
    switch (self.instr & 0x0F) {
        2 => {
            self.buffer = self.acc;
        },
        else => {}
    }
}

fn OP_Fx(self: *Intel4004) void {
    if (self.step != TIMING.X1) return;
    
    switch (self.instr & 0x0F) {
        0 => {
            self.carry = false;
            self.acc = 0;
        },
        1 => self.carry = false,
        2 => self.acc += 1,
        3 => self.carry = !self.carry,
        4 => self.acc = ~self.acc,
        5 => {
            const c: u4 = @intFromBool(self.carry);
            self.carry = ((self.acc >> 3) & 2) == 1;
            self.acc <<= 1;
            self.acc += c;
        },
        6 => {
            const c: u4 = @intFromBool(self.carry);
            self.carry = (self.acc & 2) == 1;
            self.acc >>= 1;
            self.acc += c << 3;
        },
        7 => {
            self.acc = @intFromBool(self.carry);
            self.carry = false;
        },
        8 => self.acc -= 1,
        9 => {
            self.acc = 9 + @as(u4, @intFromBool(self.carry));
            self.carry = false;
        },
        10 => self.carry = true,
        11 => {
            if (self.carry or self.acc > 9) {
                if (@as(u5, self.acc) + 6 >= 16) {
                    self.carry = true;
                }
                self.acc, _ = @addWithOverflow(self.acc, 6);
            }
        },
        12 => {
            if (self.acc <= 2) return
            else if (self.acc == 4) self.acc = 3
            else if (self.acc == 8) self.acc = 4
            else self.acc = 15;
        },
        13 => {
            self.cmram = self.acc;
        },
        else => {}
    }
}

pub const op_list: [16]opfunc = [_]opfunc{
    OP_0x, OP_1x, OP_2x, OP_3x,
    OP_4x, OP_5x, OP_6x, OP_7x,
    OP_8x, OP_9x, OP_Ax, OP_Bx,
    OP_Cx, OP_Dx, OP_Ex, OP_Fx
};