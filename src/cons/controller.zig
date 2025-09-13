const std = @import("std");
const alloc = @import("../main.zig").alloc;
const zeys = @import("zeys");
const builtin = @import("builtin");
const main = @import("../main.zig");

// this is a theoretical external device! there is no equivelant to this in real life!
pub const Controller = struct {
    signal: u1,
    out: u1,
    clock: u1,
    timing: u4,

    pub fn init() !*Controller {
        const c: *Controller = try alloc.create(Controller);

        c.signal = 0;
        c.out = 0;
        c.timing = 0;

        return c;
    }

    pub fn tick(self: *Controller) void {
        if ((self.timing % 2 == 0 and self.signal == 1) or (self.timing % 2 == 1 and self.signal == 0)) {
            self.timing, _ = @addWithOverflow(self.timing, 1);
        }

        self.clock = @truncate(self.timing % 2);
        if (builtin.target.os.tag == .windows) {
            switch (self.timing) {
                else => {},
                1 =>  self.out = @intFromBool(zeys.isPressed(zeys.VK.VK_W)),
                3 =>  self.out = @intFromBool(zeys.isPressed(zeys.VK.VK_A)),
                5 =>  self.out = @intFromBool(zeys.isPressed(zeys.VK.VK_S)),
                7 =>  self.out = @intFromBool(zeys.isPressed(zeys.VK.VK_D)),
                9 =>  self.out = @intFromBool(zeys.isPressed(zeys.VK.VK_E)),
                11 => self.out = @intFromBool(zeys.isPressed(zeys.VK.VK_Q)),
                13 => self.out = @intFromBool(zeys.isPressed(zeys.VK.VK_OEM_1)),
                15 => self.out = @intFromBool(zeys.isPressed(zeys.VK.VK_OEM_7)),
            }
        } else if (builtin.target.os.tag == .linux) {
            const keys = main.comp.keysPressed;

            switch (self.timing) {
                else => {},
                1 => self.out = @intFromBool(keys[0]),
                3 => self.out = @intFromBool(keys[1]),
                5 =>  self.out = @intFromBool(keys[2]),
                7 =>  self.out = @intFromBool(keys[3]),
                9 =>  self.out = @intFromBool(keys[4]),
                11 => self.out = @intFromBool(keys[5]),
                13 => self.out = @intFromBool(keys[6]),
                15 => self.out = @intFromBool(keys[7]),
            }
        }
    }
};
