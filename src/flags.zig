//! The C flag sets jzbuild compiles with.

const std = @import("std");

/// Strict C flags. `-fmacro-prefix-map` uses the *caller's* build root, so
/// `__FILE__` stays relative to whichever project is compiling.
pub fn strictFlags(b: *std.Build, cstd: []const u8) []const []const u8 {
    return b.allocator.dupe([]const u8, &.{
        b.fmt("-std={s}", .{cstd}),
        "-Wall",
        "-Wextra",
        "-Werror",
        "-pedantic",
        "-Wmissing-prototypes",
        "-Wmissing-variable-declarations",
        "-Wnewline-eof",
        "-Wno-error=newline-eof",
        "-Wconversion",
        "-Wno-error=conversion",
        b.fmt("-fmacro-prefix-map={s}/=", .{b.build_root.path orelse "."}),
    }) catch @panic("OOM");
}

/// Flags for test runners: `strictFlags` minus the two "should this have been
/// static?" warnings. A test case is never declared in a header, so there the
/// rule has nothing to catch and only asks every test to repeat `static`.
pub fn testFlags(b: *std.Build, cstd: []const u8) []const []const u8 {
    const relaxed = [_][]const u8{ "-Wno-missing-prototypes", "-Wno-missing-variable-declarations" };
    return std.mem.concat(b.allocator, []const u8, &.{ strictFlags(b, cstd), &relaxed }) catch @panic("OOM");
}
