const std = @import("std");
const alloc = @import("root.zig").alloc;
const zeys = @import("zeys");
const builtin = @import("builtin");
const tty_file = @import("main.zig").comp.tty_file;
const reader = std.io.getStdIn().reader();

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
            const linux = std.os.linux;
            const tty_fd = self.tty_file.handle;

            var old_settings: linux.termios = undefined;
            _ = linux.tcgetattr(tty_fd, &old_settings);

            var new_settings: linux.termios = old_settings;
            new_settings.lflag.ICANON = false;
            new_settings.lflag.ECHO = false;
            
            _ = linux.tcsetattr(tty_fd, linux.TCSA.NOW, &new_settings);

            while (true) {
                const key: u8 = reader.readByte() catch break;

                switch (self.timing) {
                    else => {},
                    1 => self.out = @intFromBool(key == 'w'),
                    3 => self.out = @intFromBool(key == 'a'),
                    5 =>  self.out = @intFromBool(key == 's'),
                    7 =>  self.out = @intFromBool(key == 'd'),
                    9 =>  self.out = @intFromBool(key == 'e'),
                    11 => self.out = @intFromBool(key == 'q'),
                    13 => self.out = @intFromBool(key == ';'),
                    15 => self.out = @intFromBool(key == '\''),
                }
            }
        
            _ = linux.tcsetattr(tty_fd, linux.TCSA.NOW, &old_settings);
        }
    }
};
