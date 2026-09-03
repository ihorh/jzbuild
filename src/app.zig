//! `app()` — tier 1. A C executable whose whole layout jzbuild infers from the
//! directories it finds beside `build.zig`.

const std = @import("std");
const flags = @import("flags.zig");
const glob = @import("glob.zig");
const cdb = @import("cdb.zig");

pub const AppOptions = struct {
    name: []const u8,
};

/// Build and install one C executable from `src/*.c`, plus one test executable
/// per `tests/*_test.c` wired to a `test` step.
///
/// Hard-errors when `src/` is missing or holds no `.c` file: inference that
/// finds nothing otherwise surfaces as a confusing link error.
pub fn app(b: *std.Build, opts: AppOptions) *std.Build.Step.Compile {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const cstd = b.option([]const u8, "c-std", "override the C standard (default c17)") orelse "c17";
    const verbose = b.option(bool, "verbose", "print the file list that inference produced") orelse false;

    const sources = collectSources(b);
    const has_include = glob.dirExists(b, "include");
    const tests = collectTests(b);

    if (verbose) {
        std.debug.print("jzbuild: app \"{s}\"\n", .{opts.name});
        for (sources) |s| std.debug.print("  source  {s}\n", .{s});
        if (has_include) std.debug.print("  include include/\n", .{});
        for (tests) |t| std.debug.print("  test    {s}\n", .{t});
    }

    const artifact = b.addExecutable(.{
        .name = opts.name,
        .root_module = module(b, target, optimize),
    });
    if (has_include) artifact.root_module.addIncludePath(b.path("include"));
    artifact.root_module.addCSourceFiles(.{
        .files = sources,
        .flags = flags.strictFlags(b, cstd),
    });
    // Invariant: every artifact is installed, because `Dependency.artifact`
    // finds artifacts by scanning install steps.
    b.installArtifact(artifact);

    addRunStep(b, artifact, opts.name);

    const test_runners = addTests(b, .{
        .target = target,
        .optimize = optimize,
        .cstd = cstd,
        .sources = sources,
        .has_include = has_include,
        .tests = tests,
    });

    var cdb_targets: std.ArrayListUnmanaged(*std.Build.Step.Compile) = .empty;
    cdb_targets.append(b.allocator, artifact) catch @panic("OOM");
    cdb_targets.appendSlice(b.allocator, test_runners) catch @panic("OOM");
    _ = cdb.addStep(b, "cdb", cdb_targets.items);

    return artifact;
}

/// Wire `zig build run-<name>`, and `run` too when no app has claimed it yet.
/// A single-app project gets both names for the same app, and a second app in
/// the same build keeps its own name without stealing `run`.
fn addRunStep(b: *std.Build, artifact: *std.Build.Step.Compile, name: []const u8) void {
    const cmd = b.addRunArtifact(artifact);
    cmd.step.dependOn(b.getInstallStep());
    // Anything after `--` on the command line reaches the app itself.
    if (b.args) |args| cmd.addArgs(args);

    const named = b.step(b.fmt("run-{s}", .{name}), b.fmt("run {s}", .{name}));
    named.dependOn(&cmd.step);

    if (b.top_level_steps.get("run") == null) {
        const plain = b.step("run", b.fmt("run {s}", .{name}));
        plain.dependOn(&cmd.step);
    }
}

fn collectSources(b: *std.Build) []const []const u8 {
    if (!glob.dirExists(b, "src"))
        std.process.fatal("jzbuild: no src/ directory in {s}. jzbuild compiles src/*.c; create it, or list sources yourself on the returned artifact.", .{b.build_root.path orelse "."});

    const sources = glob.filesWithSuffix(b, "src", ".c") catch |err|
        std.process.fatal("jzbuild: cannot read src/ in {s}: {t}", .{ b.build_root.path orelse ".", err });

    if (sources.len == 0)
        std.process.fatal("jzbuild: src/ in {s} holds no .c file. jzbuild compiles src/*.c.", .{b.build_root.path orelse "."});

    return sources;
}

fn collectTests(b: *std.Build) []const []const u8 {
    if (!glob.dirExists(b, "tests")) return &.{};
    return glob.filesWithSuffix(b, "tests", "_test.c") catch |err|
        std.process.fatal("jzbuild: cannot read tests/ in {s}: {t}", .{ b.build_root.path orelse ".", err });
}

const TestContext = struct {
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    cstd: []const u8,
    sources: []const []const u8,
    has_include: bool,
    tests: []const []const u8,
};

/// One executable per test file, each compiled with the app's sources so a test
/// reaches any function in the project. `zig build test` runs them all, and
/// `test-NAME` runs one.
///
/// A test runner skips `installArtifact`, so `zig build` leaves the install
/// prefix holding shipped binaries alone. The always-install invariant covers
/// apps and libraries, which a parent build looks up by name.
fn addTests(b: *std.Build, ctx: TestContext) []const *std.Build.Step.Compile {
    if (ctx.tests.len == 0) return &.{};

    const test_step = b.step("test", "build and run every test binary");
    const test_flags = flags.testFlags(b, ctx.cstd);
    var runners: std.ArrayListUnmanaged(*std.Build.Step.Compile) = .empty;

    for (ctx.tests) |test_file| {
        const name = std.fs.path.stem(test_file);
        const runner = b.addExecutable(.{
            .name = name,
            .root_module = module(b, ctx.target, ctx.optimize),
        });
        if (ctx.has_include) runner.root_module.addIncludePath(b.path("include"));
        runner.root_module.addIncludePath(b.path("src"));
        // The app's own sources compile a second time, under the relaxed test
        // flags. Tier 1 builds no library to link against.
        runner.root_module.addCSourceFiles(.{
            .files = withoutMain(b, ctx.sources),
            .flags = test_flags,
        });
        runner.root_module.addCSourceFiles(.{
            .files = b.allocator.dupe([]const u8, &.{test_file}) catch @panic("OOM"),
            .flags = test_flags,
        });
        const run = b.addRunArtifact(runner);
        test_step.dependOn(&run.step);
        runners.append(b.allocator, runner) catch @panic("OOM");

        // * test-NAME — one test on its own, for a tight edit-run loop.
        // Strip the "_test" suffix itself. `trimEnd` takes a character set,
        // which would eat "greet_test" down to "gr".
        const short = if (std.mem.endsWith(u8, name, "_test")) name[0 .. name.len - "_test".len] else name;
        const one = b.step(b.fmt("test-{s}", .{short}), b.fmt("run the {s} test", .{short}));
        one.dependOn(&run.step);
    }

    return runners.toOwnedSlice(b.allocator) catch @panic("OOM");
}

/// The app's sources minus `src/main.c`, whose `main` would collide with the
/// test file's own.
fn withoutMain(b: *std.Build, sources: []const []const u8) []const []const u8 {
    var kept: std.ArrayList([]const u8) = .empty;
    for (sources) |s| {
        if (std.mem.eql(u8, std.fs.path.basename(s), "main.c")) continue;
        kept.append(b.allocator, s) catch @panic("OOM");
    }
    return kept.toOwnedSlice(b.allocator) catch @panic("OOM");
}

fn module(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Module {
    return b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
}
