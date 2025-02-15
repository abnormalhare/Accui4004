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
    if (self.prev_instr == 0) {
        self.prev_instr = self.instr;
        return;
    }

    if (self.step != 5) return;

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
            (!conditions.isAccZero or (conditions.isAccZero and self.accumulator == 0)) and
            (!conditions.isCarry   or (conditions.isCarry   and self.carry           )) and
            (!conditions.isTest    or (conditions.isTest    and self.testP           ))
        ) {
            self.stack[0] = jmp;
        }
    } else {
        if (
            (!conditions.isAccZero or (conditions.isAccZero and self.accumulator != 0)) and
            (!conditions.isCarry   or (conditions.isCarry   and !self.carry          )) and
            (!conditions.isTest    or (conditions.isTest    and !self.testP          ))
        ) {
            self.stack[0] = jmp;
        }
    }

    self.prev_instr = 0;
}

fn OP_FIM(self: *Intel4004, reg: u8) void {
    if (self.prev_instr == 0) {
        self.prev_instr = self.instr;
        return;
    }

    if (self.step != 5) return;

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


fn TEMP(self: *Intel4004) void { _ = self; }

pub const op_list: [16]opfunc = [_]opfunc{
    OP_0x, OP_1x, OP_2x, TEMP,
    TEMP , TEMP , TEMP , TEMP,
    TEMP , TEMP , TEMP , TEMP,
    TEMP , TEMP , TEMP , TEMP
};