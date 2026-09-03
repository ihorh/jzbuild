# PLAN

Working notes for the current stretch. Transient: delete a section once it
lands, and rewrite the file freely.

## Settled Decisions

**Setting a field in `build.zig` withdraws its command-line option.** Pinning `.std = "c99"` withdraws
`-Dc-std`, and pinning `.optimize = .ReleaseSmall` withdraws `-Doptimize`. The
value is a requirement of the project, so a caller who overrode it would break
the build. Leave a field inferred and its option stays available.

This follows from the core rule that `null` means infer. It costs something
real: a project that pins an optimization mode loses the knob for debugging.
Revisit only if that bites.

## Repository Layout

```
build.zig          the public API — this is what a consumer @imports
build.zig.zon      package name, fingerprint, .paths
src/               implementation, imported by build.zig
examples/          complete projects that build against this repo
README.md
PLAN.md            this file
LICENSE
```

`build.zig` is the library, because `@import("jzbuild")` inside a consumer's
build script resolves to the package's build script. Implementation splits into
`src/*.zig` and `build.zig` re-exports the public names.

`.paths` in `build.zig.zon` lists `build.zig`, `build.zig.zon`, and `src`. It
leaves out `examples`, so a consumer fetching the package downloads none of
them.

Each example carries its own `build.zig.zon` with `.jzbuild = .{ .path = "../.." }`.

## Done: Tier 1, Happy Path

One example, `examples/basic`, and enough of `app()` to build it.

```
examples/basic/
  build.zig            jzbuild.app(b, .{ .name = "basic" });
  build.zig.zon
  src/main.c           calls greet()
  src/greet.c
  include/greet.h
  tests/greet_test.c
```

Two source files rather than one is deliberate. It is the smallest project that
proves the glob works, and it settles the open question below for free.

`app()` in this stretch:

- collect `src/*.c`
- add `include/` when the directory exists
- strict flags, `c17`, libc, host target, `standardOptimizeOption`
- `installArtifact`
- one test executable per `tests/*_test.c`, linked against the sources, wired to
  a `test` step

No overrides yet. Every field beyond `.name` comes later, driven by a real
consumer.

Built and verified. `app()` also wires `run-NAME`, and claims plain `run` when
no earlier app took it. Anything after `--` reaches the app.

Two questions this stretch left open:

- **Test runners install to `zig-out/bin`.** That follows the always-install
  invariant, and it puts `greet_test` beside the app. Decide who the invariant covers. Either a
  parent build looks test runners up by name, or runners stay out of the
  install prefix.
- **`app()` returns the artifact, so a call site writes `_ =`.** Kept. One constructor beats a pair
  that differ only in what they hand back.

## Answered: Globbing Works

**A new `src/*.c` is picked up without touching `build.zig`.** Tested on
`examples/basic` under Zig 0.16.0: dropping `src/second.c` in and running
`zig build` linked it, with every `.zig` file keeping its earlier mtime. The
stricter case passes too, where a file appears and nothing else changes at all.
Removing a file shrinks the list again.

Zig re-runs the build script and the fresh glob takes effect. `sources` stays
optional, and tier 1 holds.

## Next, in Order

1. **A single-source app** — `src/main.c` alone, built from outside this repo.
   Confirms `app()` works as a fetched dependency.
2. **A freestanding binary, cross-compiled to two targets** — needs `libc`,
   per-artifact `target`, `defines`, `entry`, `install_to`, and `flags.std` /
   `.add`. Each is a new optional field. A project like this often asserts a
   binary size budget, so watch how Zig's optimize modes line up against
   clang's `-O` levels.
3. **A library inside a multi-package workspace** — needs `install_headers`,
   and `header_deps` for a sibling package's include directory.

## Before the First Public Commit

- Fingerprint picked: `0x6391e7b4c5d4452d`. Keep it. Changing it after a
  consumer pins a hash is painful.
- `.gitignore` covers `.zig-cache/` and `zig-out/`.
