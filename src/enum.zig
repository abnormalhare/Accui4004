pub const TIMING = enum(u3) {
    A1, A2, A3,
    M1, M2,
    X1, X2, X3
};

pub fn incStep(step: *TIMING) void {
    const val: u3, _ = @addWithOverflow(@intFromEnum(step.*), 1);
    step.* = @enumFromInt(val);
}