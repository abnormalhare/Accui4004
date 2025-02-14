const std = @import("std");
const alloc = std.heap.c_allocator;

const Intel4001 = @import("4001.zig").Intel4001;
const Intel4004 = @import("4004.zig").Intel4004;
const Clock = @import("clock.zig");

const Computer = struct {
    enable_state: u8,
    cpu: Intel4001,
    roms: [16]Intel4004,

    fn set_bus(self: *Computer, isCpu: bool, romNum: u4) void {
        var bus: u4 = 0;
        
        if (isCpu) {
            bus = self.cpu.buffer;
        } else {
            bus = self.roms[romNum].buffer;
        }

        self.cpu.buffer = bus;
        for (&self.roms) |*rom| {
            rom.buffer = bus;
        }
    }

    fn tick(self: *Computer) void {
        Clock.tick();
        self.cpu.tick();
        self.set_bus(true, 0);
        
        for (&self.roms) |*rom| {
            rom.tick();
        }

        Clock.p1 = false;
        Clock.p2 = false;
    }
};

pub fn main() !void {
    const comp = try alloc.create(Computer);
    
    Clock.currTime = std.time.nanoTimestamp();

    while (true) {
        comp.tick();
    }
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
