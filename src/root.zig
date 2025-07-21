const std = @import("std");
pub const alloc = std.heap.c_allocator;

pub const ROM_SIZE: usize = 0x100;