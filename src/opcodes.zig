const Intel4004 = @import("4004.zig").Intel4004;

fn NOP() void {
}

fn JCN(self: *Intel4004, op: u8) void {
    const condition = op & 0x0F;
}