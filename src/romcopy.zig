const std = @import("std");

fn splitCopyROM(dest: *[0x200 * 0x10]u4, source: [0x100 * 0x10]u8) void {
    var i: u32 = 0;
    while (i < 0x200) {
        dest[i * 2 + 0] = @intCast(source[i] >> 4);
        dest[i * 2 + 1] = @truncate(source[i]);
        i += 1;
    }
}

pub fn getROM(filename: []const u8) !*u4 {
    var file = try std.fs.cwd().openFile(filename, .{});
    defer file.close();

    var str: [0x100 * 0x10]u8 = [_]u8{0} ** (0x100 * 0x10);
    var checkStr: [3]u8 = .{ 0, 0, 0 };
    _ = try file.read(&checkStr);
    if (!std.mem.eql(u8, &checkStr, "i44")) {
        return error.NotI4004File;
    }

    try file.seekTo(0x10);
    _ = try file.read(&str);

    var rom: [0x200 * 0x10]u4 = [_]u4{0} ** (0x200 * 0x10);

    splitCopyROM(&rom, str);

    return &rom[0];
}

pub fn copyROM(dest: *[0x200]u4, source: *u4) void {
    var s: *u4 = source;
    var i: u16 = 0;
    while (i < 0x200) {
        dest[i] = s.*;
        s = @ptrFromInt(@intFromPtr(s) + 1);
        i += 1;
    }
}
