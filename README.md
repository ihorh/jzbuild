# jzbuild

Build a C project with `zig build`. A standard project — `src/`, `include/`,
`tests/` — needs a short `build.zig`: `jzbuild` infers whatever follows a
convention, and you spell out only what is unusual about your project.

That Zig's build system can build plain C is widely repeated and thinly
documented. This repo is that claim worked through end to end: a convention
layer over `std.Build`, and the reasoning behind each piece of it. Read it, use
it, or fork it and cut it to your own shape.

> **Scope.** A demonstration of an approach, not a product. `app()` works and the
> first example below builds and runs today; the second example shows
> `project()`, which is still a design target. The API keeps moving, there is no
> release, and nothing here comes with support promises.
>
> Built and verified against **Zig 0.16.0**. Zig's build API changes between
> versions, so read this as a snapshot pinned to that one.

![A terminal recording: `cat build.zig` shows a five-line build file, `zig build` compiles and runs it, then `zig build -Dtarget=aarch64-linux` cross-compiles to an ELF aarch64 binary on macOS with no extra toolchain.](docs/demo.gif)

## What It Looks Like

A project with `src/`, `include/`, and `tests/`:

```zig
const std = @import("std");
const jzbuild = @import("jzbuild");

pub fn build(b: *std.Build) void {
    _ = jzbuild.app(b, .{ .name = "hello" });
}
```

That compiles every `src/*.c` and puts `include/` on the header path. It
installs the binary and wires a `run` step. It builds one test binary per
`tests/*_test.c` behind a `test` step. `app()` hands back the
`*std.Build.Step.Compile` for anything else you want to do to it.

When a project needs something the convention does not cover, declare that one
thing. Here is a freestanding binary cross-compiled to two targets. `project()`
handles this shape once it exists:

```zig
pub fn build(b: *std.Build) void {
    const p = jzbuild.project(b, .{
        .flags = .{ .std = "c99", .add = &.{"-Wno-empty-translation-unit"} },
        .libc = false,
    });

    for (targets) |t| _ = p.app(.{
        .name = "hello",
        .target = p.triple(t.triple),
        .entry = .{ .symbol_name = t.entry },
    });
}
```

The layout stays inferred. Only the unusual part appears in the file.

## Installation

New to Zig's package manager? Start with the
[quick start](docs/quickstart.md), which builds a hello-world project from an
empty directory.

Fetch the package. The command records it in your `build.zig.zon`:

```bash
zig fetch --save git+https://github.com/ihorh/jzbuild
```

That writes a `.jzbuild` entry naming the exact commit it resolved, plus a hash
of what it downloaded:

```zig
.dependencies = .{
    .jzbuild = .{
        .url = "git+https://github.com/ihorh/jzbuild#a2c9ef0c67edf8a185b38f5c0e8d4c7a71b744d8",
        .hash = "jzbuild-0.0.0-LUXUxVlEAADvdxgYoPnMFfqBqgRFnye835x1j0yjTjMF",
    },
},
```

The commit is pinned, so your build stays identical until you fetch again.
Append `#v0.1.0` to the URL to fetch a tag instead of the default branch.

`zig fetch` unpacks the package into a local cache directory (`.zig-cache/` by
default, or `zig-pkg/` if the project points its cache elsewhere). Gitignore
that directory — the `.hash` in `build.zig.zon` is what reproduces it, not the
directory's contents.

Then import it at the top of `build.zig`:

```zig
const jzbuild = @import("jzbuild");
```

The import name matches the key in `.dependencies`, and it resolves to the
package's own `build.zig`. jzbuild ships helpers rather than an artifact, so that
import is the whole setup.

Upgrading means running that command again.

## Steps

| Command | What it does |
|---|---|
| `zig build` | compiles and installs every artifact |
| `zig build test` | builds and runs every test binary |
| `zig build test-NAME` | runs one test, `tests/NAME_test.c` |
| `zig build run` | runs the app |
| `zig build run-NAME` | runs one named app, for a project declaring several |
| `zig build cdb` | writes `compile_commands.json` to the project root |

Arguments after `--` reach the app: `zig build run -- --flag value`.

Plain `zig build` compiles and installs the app alone. Test binaries build only
when you ask for a test step, and they stay out of the install prefix.

`cdb` reads the actual build graph — the app's sources and every test
runner's — so its output matches what `zig build` really compiles, flags
included. Point clangd at it once and re-run `zig build cdb` whenever sources
or flags change; VS Code's clangd extension picks up a
`compile_commands.json` in the workspace root automatically, no settings
needed.

## Command-Line Options

A jzbuild project inherits Zig's standard options and adds two.

| Option | Values | Default |
|---|---|---|
| `-Dtarget=` | any Zig target triple, such as `aarch64-macos` | the host |
| `-Dcpu=` | CPU features to add or subtract | the host's |
| `-Doptimize=` | `Debug`, `ReleaseSafe`, `ReleaseFast`, `ReleaseSmall` | `Debug` |
| `-Dc-std=` | any value clang accepts for `-std=` | `c17` |
| `-Dverbose` | prints the file list that inference produced | off |

Reach for `-Dverbose` when a source file fails to compile and you suspect
jzbuild never found it.

**An option disappears once `build.zig` sets the field behind it.** A project
that pins `.std = "c99"` publishes no `-Dc-std`. That value is a requirement of
the project rather than a preference of whoever runs the build. Leave the field
inferred and the option stays available.

## Permanent Customization

Anything you want to hold across every build goes in `build.zig`. Reach for
`project()`, which takes the settings once and hands them to each artifact it
builds.

```zig
pub fn build(b: *std.Build) void {
    const p = jzbuild.project(b, .{
        .flags = .{
            .base = .strict,                  // the default warning set
            .std = "c11",
            .add = &.{"-Wshadow"},
            .remove = &.{"-Wconversion"},
        },
        .optimize = .ReleaseSafe,
    });

    _ = p.app(.{ .name = "hello" });
}
```

The four settings above cover most of what a project ever needs to change:

| Field | Use it to |
|---|---|
| `flags.base` | choose a warning set — `.strict`, `.recommended`, or `.minimal` |
| `flags.std` | pin the C standard |
| `flags.add` / `.remove` | adjust one flag without restating the set |
| `optimize` | pin an optimization mode the project depends on |

For a change that touches one artifact rather than the project, pass the field
to `app()` or `lib()` instead. For anything the options cannot say, use the
`*std.Build.Step.Compile` that every constructor returns.

## How It Works

Every option field is optional, and leaving it out means "infer this". Overriding one field keeps the
inference on all the others, because a project opts into no standard-versus-custom
mode.

The constructors return the underlying `*std.Build.Step.Compile`, so anything
jzbuild cannot express you wire yourself in plain Zig. The helpers are a
shortcut, never a wall.

## Documentation

- [Quick start](docs/quickstart.md) — a hello-world project, step by step,
  starting from an empty directory.

Each directory under [`examples/`](examples/) is a complete project that builds
against the jzbuild in this repo. They double as the test suite. An example that
stops building condemns the change that broke it.

## Requirements

Zig 0.16.0, and nothing else — Zig ships its own C compiler.

Verified against 0.16.0, which is also the `minimum_zig_version` in
`build.zig.zon`. Zig's build API is still changing between releases; on a newer
Zig, expect any breakage to land here rather than in your own `build.zig`.

## Acknowledgements

Designed and built with AI assistance from Claude by Anthropic.

## License

MIT. See [LICENSE](LICENSE).
