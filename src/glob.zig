//! Directory inference. Everything jzbuild learns about a project's layout it
//! learns here, by listing `b.build_root.handle` at configure time.

const std = @import("std");

/// Whether `sub_path` exists under the build root and is a directory.
pub fn dirExists(b: *std.Build, sub_path: []const u8) bool {
    const io = b.graph.io;
    var dir = b.build_root.handle.openDir(io, sub_path, .{}) catch return false;
    dir.close(io);
    return true;
}

/// Every entry directly inside `sub_path` whose name ends with `suffix`, sorted
/// by name and returned as build-root-relative paths (`src/greet.c`).
///
/// Returns an error only when the directory cannot be listed; an existing
/// directory with no match yields an empty slice, which the caller judges.
pub fn filesWithSuffix(
    b: *std.Build,
    sub_path: []const u8,
    suffix: []const u8,
) ![]const []const u8 {
    const io = b.graph.io;
    var dir = try b.build_root.handle.openDir(io, sub_path, .{ .iterate = true });
    defer dir.close(io);

    var found: std.ArrayList([]const u8) = .empty;
    var it = dir.iterate();
    while (try it.next(io)) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.name, suffix)) continue;
        try found.append(b.allocator, b.pathJoin(&.{ sub_path, entry.name }));
    }

    // Directory order is whatever the filesystem hands back. Sorting keeps the
    // compile command — and so the build cache — stable across machines.
    std.mem.sort([]const u8, found.items, {}, lessThan);
    return found.toOwnedSlice(b.allocator);
}

fn lessThan(_: void, a: []const u8, b: []const u8) bool {
    return std.mem.order(u8, a, b) == .lt;
}
