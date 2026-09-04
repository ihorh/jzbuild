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
/// static?" warnings, plus `-UNDEBUG`. A test case is never declared in a
/// header, so the "static?" rule has nothing to catch there and only asks
/// every test to repeat `static`.
///
/// `-UNDEBUG` counters zig's own C driver, which silently defines `NDEBUG`
/// (and so strips every `assert`) under `-OReleaseFast`/`-OReleaseSmall`,
/// unlike `-ODebug`/`-OReleaseSafe`. A test binary that leans on `assert` for
/// its actual check — comparing real output to a golden, say — would
/// otherwise pass by doing nothing at those two optimize levels, having
/// never run the check at all. The app binary itself isn't test code, so it
/// keeps zig's normal optimize-level convention and stays out of this.
pub fn testFlags(b: *std.Build, cstd: []const u8) []const []const u8 {
    const extra = [_][]const u8{ "-Wno-missing-prototypes", "-Wno-missing-variable-declarations", "-UNDEBUG" };
    return std.mem.concat(b.allocator, []const u8, &.{ strictFlags(b, cstd), &extra }) catch @panic("OOM");
}
