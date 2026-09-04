# Proposal: Expose LTO, and Ignore It on macOS

Uncommitted note, written 2026-09-05 from jsptx's benchmark work.

## What jsptx Ran Into

jsptx splits its SIMD classifier into its own translation unit, so
`jsp_classify64` compiles to a `bl` inside the hot loop, once per 64-byte
block. Disassembly at `-O2` on arm64 shows that call surviving. Building the
same sources with `clang -O3 -flto` inlines the classifier into the loop, and
the binary then holds no call to any classifier.

That difference decides whether a throughput benchmark measures the classifier
or the call around it, so the project needs LTO to be reachable from
`zig build`.

## Reaching It Today

A consumer can already set it on the artifact `app()` returns, since
`lto` is a field on `std.Build.Step.Compile` (`Compile.zig:177` in zig 0.16):

```zig
const exe = jzbuild.app(b, .{ .name = "jsptx" });
exe.lto = .full;
```

Two nearby guesses fail to compile. Both look right, so both are worth
naming: `exe.want_lto` and `exe.root_module.lto`.

This works. It also leaves the test executables `app()` builds without LTO,
which is probably fine and is certainly undocumented.

## The Request

Give `AppOptions` an `lto: ?std.zig.LtoMode = null` field, following the
settled decision in `PLAN.md`. A `null` infers and keeps a `-Dlto` option
available, and a pinned value withdraws that option.

One question a caller cannot answer from outside: does the mode reach the test
executables too, or the app alone?

## macOS Refuses, and jzbuild Should Say So Once

zig cannot link Mach-O with LLD, and LTO needs LLD. Both errors are terse:

```
error: LTO requires using LLD
error: using LLD to link macho files is unsupported     # with use_lld = true
```

A developer on macOS hits the first one, sets `use_lld`, and hits the second.
Neither message says the combination is impossible on this target rather than
misconfigured.

So when the resolved target emits Mach-O, drop the LTO setting and print one
warning naming the target. Failing a maintainer's laptop build over a knob
that cannot work there is worse than quietly doing less. Checking the object
format rather than the OS tag also covers iOS and the simulator targets.
