const alloc = @import("../main.zig").alloc;

pub const Intel3205 = struct {
    in: u3,
    enable: u3,
    out: [8]u1,

    pub fn init() !*Intel3205 {
        const i = try alloc.create(Intel3205);

        i.in = 0;
        i.enable = 0;
        i.out = .{ 0, 0, 0, 0, 0, 0, 0, 0 };

        return i;
    }

    pub fn tick(self: *Intel3205) void {
        self.out = .{
            @intFromBool(self.in == 0),
            @intFromBool(self.in == 1),
            @intFromBool(self.in == 2),
            @intFromBool(self.in == 3),
            @intFromBool(self.in == 4),
            @intFromBool(self.in == 5),
            @intFromBool(self.in == 6),
            @intFromBool(self.in == 7),
        };
    }
};
