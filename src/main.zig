const std = @import("std");
const alloc = @import("root.zig").alloc;
const Motherboard = @import("motherboard.zig").Motherboard;
const Clock = @import("4801.zig");

pub fn main() !void {
    var filename: []u8 = undefined;
    // startup
    var argsIterator = try std.process.ArgIterator.initWithAllocator(alloc);
    defer argsIterator.deinit();

    _ = argsIterator.next();
    if (argsIterator.next()) |path| {
        filename = try alloc.alloc(u8, path.len);
        @memcpy(filename, path);
    } else {
        std.debug.print("Command Usage: [emu].exe [filename].i44 (step|cycle_step|subcycle_step)", .{});
        return;
    }

    var comp: *Motherboard = try Motherboard.init(filename);
    Clock.setTime = std.time.nanoTimestamp();

    if (argsIterator.next()) |run| {
        comp.step = @as(u2, @intFromBool(std.mem.eql(u8, run, "step")));
        comp.step += @as(u2, @intFromBool(std.mem.eql(u8, run, "cycle_step"))) * 2;
        comp.step += @as(u2, @intFromBool(std.mem.eql(u8, run, "subcycle_step"))) * 3;
    } else {
        comp.step = 0;
    }

    std.debug.print("\x1B[H\x1B[2J", .{});

    // emulate
    var count: u32 = 0;
    comp.cpu.reset = true;
    for (&comp.roms) |*rom| {
        rom.*.reset = true;
    }
    for (&comp.rams) |*ram| {
        ram.*.reset = true;
    }
    while (true) {
        Clock.tick();
        if (Clock.p2) {
            count += 1;
        }
        try comp.tick();
        if (count == 64) {
            comp.cpu.reset = false;
            for (&comp.roms) |*rom| {
                rom.*.reset = false;
            }
            for (&comp.rams) |*ram| {
                ram.*.reset = false;
            }
        }
    }
}
