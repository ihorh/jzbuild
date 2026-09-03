//! cdb.zig — generate compile_commands.json from the build graph.
//!
//! All the logic lives here; app.zig only calls `addStep`. Given a set of
//! compile artifacts, it reads each one's real C sources, include dirs, and
//! flags and writes a compile_commands.json clangd can consume. No external
//! dependency, and it reads the actual build graph so there is no separate
//! flag list to keep in sync.

const std = @import("std");
const Build = std.Build;
const Step = Build.Step;

/// Wire a `<name>` step (e.g. "cdb") that writes compile_commands.json to the
/// build root, covering every C source in `targets`.
pub fn addStep(b: *Build, name: []const u8, targets: []const *Step.Compile) *Step {
    const gen = b.allocator.create(Gen) catch @panic("OOM");
    gen.* = .{
        .step = Step.init(.{
            .id = .custom,
            .name = "gen compile_commands.json",
            .owner = b,
            .makeFn = make,
        }),
        .targets = b.allocator.dupe(*Step.Compile, targets) catch @panic("OOM"),
    };
    const top = b.step(name, "Generate compile_commands.json for clangd");
    top.dependOn(&gen.step);
    return top;
}

const Gen = struct {
    step: Step,
    targets: []*Step.Compile,
};

fn make(step: *Step, opts: Step.MakeOptions) anyerror!void {
    _ = opts;
    const gen: *Gen = @fieldParentPtr("step", step);
    const b = step.owner;
    const a = b.allocator;

    const build_root = b.build_root.path orelse ".";

    var out: std.ArrayListUnmanaged(u8) = .empty;
    try out.appendSlice(a, "[\n");
    var first = true;

    for (gen.targets) |t| {
        const mod = t.root_module;

        var incs: std.ArrayListUnmanaged([]const u8) = .empty;
        for (mod.include_dirs.items) |inc| switch (inc) {
            .path, .path_system, .path_after => |lp| {
                const p = lp.getPath3(b, step);
                try incs.append(a, b.pathResolve(&.{ p.root_dir.path orelse ".", p.sub_path }));
            },
            else => {},
        };

        for (mod.link_objects.items) |lo| switch (lo) {
            .c_source_file => |csf| {
                const p = csf.file.getPath3(b, step);
                const file = b.pathResolve(&.{ p.root_dir.path orelse ".", p.sub_path });
                try emitEntry(a, &out, &first, build_root, file, csf.flags, incs.items);
            },
            .c_source_files => |csfs| {
                const bp = csfs.root.getPath3(b, step);
                const base = b.pathResolve(&.{ bp.root_dir.path orelse ".", bp.sub_path });
                for (csfs.files) |f| {
                    const file = b.pathResolve(&.{ base, f });
                    try emitEntry(a, &out, &first, build_root, file, csfs.flags, incs.items);
                }
            },
            else => {},
        };
    }

    try out.appendSlice(a, "\n]\n");
    try b.build_root.handle.writeFile(b.graph.io, .{ .sub_path = "compile_commands.json", .data = out.items });
}

fn emitEntry(
    a: std.mem.Allocator,
    out: *std.ArrayListUnmanaged(u8),
    first: *bool,
    dir: []const u8,
    file: []const u8,
    flags: []const []const u8,
    incs: []const []const u8,
) !void {
    if (!first.*) try out.appendSlice(a, ",\n");
    first.* = false;

    try out.appendSlice(a, "  {\n    \"directory\": ");
    try jsonStr(a, out, dir);
    try out.appendSlice(a, ",\n    \"file\": ");
    try jsonStr(a, out, file);
    try out.appendSlice(a, ",\n    \"arguments\": [");

    var need_comma = false;
    try emitArg(a, out, &need_comma, "clang");
    for (flags) |fl| try emitArg(a, out, &need_comma, fl);
    for (incs) |inc| {
        try emitArg(a, out, &need_comma, "-I");
        try emitArg(a, out, &need_comma, inc);
    }
    try emitArg(a, out, &need_comma, "-c");
    try emitArg(a, out, &need_comma, file);

    try out.appendSlice(a, "]\n  }");
}

fn emitArg(a: std.mem.Allocator, out: *std.ArrayListUnmanaged(u8), need_comma: *bool, arg: []const u8) !void {
    if (need_comma.*) try out.appendSlice(a, ", ");
    need_comma.* = true;
    try jsonStr(a, out, arg);
}

fn jsonStr(a: std.mem.Allocator, out: *std.ArrayListUnmanaged(u8), s: []const u8) !void {
    try out.append(a, '"');
    for (s) |c| switch (c) {
        '"' => try out.appendSlice(a, "\\\""),
        '\\' => try out.appendSlice(a, "\\\\"),
        '\n' => try out.appendSlice(a, "\\n"),
        '\t' => try out.appendSlice(a, "\\t"),
        '\r' => try out.appendSlice(a, "\\r"),
        else => try out.append(a, c),
    };
    try out.append(a, '"');
}
