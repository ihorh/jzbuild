# Quick Start

Build and run a C program that prints `Hello, world!`. Every file you need is
written out in full, and every command is one you can paste.

This walkthrough covers one source file and nothing else. Tests, extra modules,
and headers come later.

## What You Need

Zig 0.16.0 or newer, and nothing else. Zig ships its own C compiler, so it
replaces clang, make, and the rest of a system toolchain.

```bash
zig version
```

## 1. Make the Project

jzbuild finds your code by looking in fixed directories, so the layout comes
first:

```bash
mkdir -p hello/src
cd hello
```

You end up with this, and the next three steps fill it in:

```
hello/
├── build.zig        how to build the project
├── build.zig.zon    what the project is, and what it depends on
└── src/
    └── main.c       your program
```

## 2. Write the Program

`src/main.c`:

```c
#include <stdio.h>

int main(void) {
    printf("Hello, world!\n");
    return 0;
}
```

## 3. Declare the Package

`build.zig.zon` names your project and lists its dependencies. Zig reads it
before anything else.

```zig
.{
    .name = .hello,
    .version = "0.1.0",
    .minimum_zig_version = "0.16.0",
    .dependencies = .{},
    .paths = .{ "build.zig", "build.zig.zon", "src" },
}
```

Field by field:

| Field | Means |
|---|---|
| `.name` | your project's name, written as `.name` rather than `"name"` |
| `.version` | your version, in `major.minor.patch` form |
| `.minimum_zig_version` | the oldest Zig that can build this |
| `.dependencies` | empty for now; step 4 fills it in |
| `.paths` | which files belong to the package |

One field is missing on purpose. Run `zig build` now and it says so:

```
error: missing top-level 'fingerprint' field; suggested value: 0x3610a68656c20947
```

A fingerprint identifies your package for as long as it exists. Copy the value
Zig suggests into the file, right below `.version`. **Your number differs from
the one above**, so use the one your own error message prints:

```zig
    .fingerprint = 0x3610a68656c20947,
```

## 4. Add jzbuild

```bash
zig fetch --save git+https://github.com/ihorh/jzbuild
```

That downloads jzbuild and writes it into your `.dependencies`. The field now
reads something like this:

```zig
    .dependencies = .{
        .jzbuild = .{
            .url = "git+https://github.com/ihorh/jzbuild#a2c9ef0c67edf8a185b38f5c0e8d4c7a71b744d8",
            .hash = "jzbuild-0.0.0-LUXUxVlEAADvdxgYoPnMFfqBqgRFnye835x1j0yjTjMF",
        },
    },
```

Zig rewrote the URL to name one exact commit, and recorded a hash of what it
downloaded. Your build now stays identical until you run that command again.

## 5. Write the Build Script

`build.zig`:

```zig
const std = @import("std");
const jzbuild = @import("jzbuild");

pub fn build(b: *std.Build) void {
    _ = jzbuild.app(b, .{ .name = "hello" });
}
```

Three lines carry the whole file:

- `@import("jzbuild")` matches the `.jzbuild` key you added in step 4.
- `app()` builds an executable named `hello`, and works out the rest by looking
  at your directories.
- `_ =` tells Zig you are ignoring what `app()` hands back. The return value
  becomes useful once you want to customize the executable, and until then Zig
  insists you say you are dropping it.

## 6. Build and Run

```bash
zig build run
```

```
Hello, world!
```

To build without running, use `zig build`. Your executable lands in
`zig-out/bin/hello`, and you can run it directly:

```bash
zig build
./zig-out/bin/hello
```

To pass arguments to your program, put them after `--`:

```bash
zig build run -- one two three
```

## What Just Happened

You never told jzbuild where your code was. It looked, using rules you can rely
on:

| jzbuild looks for | And does |
|---|---|
| `src/*.c` | compiles every one of them |
| `include/` | puts it on the header search path, when it exists |
| `tests/*_test.c` | builds one test binary each, behind a `zig build test` step |

Add `src/greet.c` tomorrow and it compiles, with no edit to `build.zig`. That is
the point of the library.

Your program compiled under a strict warning set, with warnings treated as
errors. Code that compiles quietly elsewhere may well fail here, and the message
you get is the point rather than an obstacle.

## Next Steps

- `zig build --help` lists every step and option this project understands.
- The [README](../README.md) covers changing the C standard, adjusting warnings,
  and pinning an optimization mode.
