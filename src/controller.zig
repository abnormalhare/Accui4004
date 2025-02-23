const std = @import("std");
const alloc = @import("root.zig").alloc;
const zeys = @import("zeys");

// this is a theoretical external device! there is no equivelant to this in real life!
pub const Controller = struct {
    io: u4,

    pub fn init() !*Controller {
        const c: *Controller = try alloc.create(Controller);

        c.io = 0;

        return c;
    }

    pub fn tick(self: *Controller) void {
        if (zeys.isPressed(zeys.VK.VK_1)) self.io |= 0x1 else self.io &= 0xE;
        if (zeys.isPressed(zeys.VK.VK_2)) self.io |= 0x2 else self.io &= 0xD;
        if (zeys.isPressed(zeys.VK.VK_3)) self.io |= 0x4 else self.io &= 0xB;
        if (zeys.isPressed(zeys.VK.VK_4)) self.io |= 0x8 else self.io &= 0x7;
    }
};
