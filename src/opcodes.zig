const zeys = @import("zeys");

const Intel4004 = @import("4004.zig").Intel4004;

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
    if (self.step != 5) return;
    
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

fn OP_FIM(self: *Intel4004, reg: u8) void {
    if (self.step != 5) return;
    
    if (self.prev_instr == 0) {
        self.prev_instr = self.instr;
        return;
    }

    self.reg[reg + 0] = @intCast((self.instr & 0xF0) >> 4);
    self.reg[reg + 1] = @intCast((self.instr & 0x0F) >> 0);

    self.prev_instr = 0;
}

fn OP_SRC(self: *Intel4004, reg: u8) void {
    switch (self.step) {
        6 => {
            self.cm = 1;
            self.buffer = self.reg[reg + 0];
        },
        7 => self.buffer = self.reg[reg + 1],
        else => {}
    }
}

fn OP_2x(self: *Intel4004) void {
    const amnt: u8 = (self.instr >> 1) << 1;
    if (self.instr % 2 == 0) {
        OP_FIM(self, amnt);
    } else {
        OP_SRC(self, amnt);
    }
}

fn OP_FIN(self: *Intel4004, reg: u8) void {
    _ = self; _ = reg;
}

fn OP_JIN(self: *Intel4004, reg: u8) void {
    if (self.step != 5) return;

    const pc: u12 = self.stack[0];
    self.stack[0] = (pc & 0xF00) + @as(u12, self.reg[reg] << 4) + @as(u12, self.reg[reg + 1]);
}

fn OP_3x(self: *Intel4004) void {
    const amnt: u8 = (self.instr >> 1) << 1;
    if (self.instr % 2 == 0) {
        OP_FIN(self, amnt);
    } else {
        OP_JIN(self, amnt);
    }
}

// JUN
fn OP_4x(self: *Intel4004) void {
    if (self.step != 5) return;

    if (self.prev_instr == 0) {
        self.prev_instr = self.instr;
        return;
    }

    self.stack[0] = (@as(u12, self.prev_instr & 0x0F) << 8) + @as(u12, self.instr);
}

// JMS
fn OP_5x(self: *Intel4004) void {
    if (self.step != 5) return;

    if (self.prev_instr == 0) {
        self.prev_instr = self.instr;
        return;
    }

    self.stack[3] = self.stack[2];
    self.stack[2] = self.stack[1];
    self.stack[1] = self.stack[0];

    self.stack[0] = (@as(u12, self.prev_instr & 0x0F) << 8) + @as(u12, self.instr);
}

// INC
fn OP_6x(self: *Intel4004) void {
    self.reg[self.instr & 0x0F] += 1;
}

// ADD
fn OP_8x(self: *Intel4004) void {
    if (@as(u5, self.acc) + @as(u5, self.reg[self.instr & 0x0F]) > 0xF)
        self.carry = 1;
    self.acc += self.reg[self.instr & 0x0F];
}

// SUB
fn OP_9x(self: *Intel4004) void {
    if (@as(u5, self.acc) - @as(u5, self.reg[self.instr & 0x0F]) > 0xF)
        self.carry = 0;
    self.acc -= self.reg[self.instr & 0x0F];
}

// LD
fn OP_Ax(self: *Intel4004) void {
    self.acc = self.reg[self.instr & 0x0F];
}

// XCH
fn OP_Bx(self: *Intel4004) void {
    const temp = self.acc;
    self.acc = self.reg[self.instr & 0x0F];
    self.reg[self.instr & 0x0F] = temp;
}

// BBL
fn OP_Cx(self: *Intel4004) void {
    self.stack[0] = self.stack[1];
    self.stack[1] = self.stack[2];
    self.stack[2] = self.stack[3];

    self.acc = self.buffer;
}

// LDM
fn OP_Dx(self: *Intel4004) void {
    self.acc = self.buffer;
}

fn OP_Fx(self: *Intel4004) void {
    switch (self.instr & 0x0F) {
        0 => {
            self.carry = 0;
            self.acc = 0;
        },
        1 => self.carry = 0,
        2 => self.acc += 1,
        3 => self.carry = !self.carry,
        4 => self.acc = ~self.acc,
        5 => {
            const c = self.carry;
            self.carry = (self.acc >> 7) & 2;
            self.acc <<= 1;
            self.acc += @intFromBool(c);
        },
        6 => {
            const c = self.carry;
            self.carry = self.acc & 2;
            self.acc >>= 1;
            self.acc += @intFromBool(c) << 3;
        },
        7 => {
            self.acc = @intFromBool(self.carry);
            self.carry = 0;
        },
        8 => self.acc -= 1,
        9 => {
            self.acc = 9 + @intFromBool(self.carry);
            self.carry = 0;
        },
        10 => self.carry = 1,
        11 => {
            if (self.carry or self.acc > 9) {
                if (@as(u5, self.acc) + 6 >= 16) {
                    self.carry = 1;
                }
                self.acc += 6;
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
        }
    }
}

fn TEMP(self: *Intel4004) void { _ = self; }

pub const op_list: [16]opfunc = [_]opfunc{
    OP_0x, OP_1x, OP_2x, OP_3x,
    OP_4x, OP_5x, OP_6x, TEMP,
    OP_8x, OP_9x, OP_Ax, OP_Bx,
    OP_Cx, OP_Dx, TEMP , OP_Fx
};