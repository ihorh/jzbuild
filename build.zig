//! jzbuild — build helpers for C projects that build with `zig build`.
//!
//! This file is the package's public API: `@import("jzbuild")` inside a
//! consumer's build script resolves to it. The implementation lives in
//! `src/*.zig`; this file re-exports the public names and nothing else.

const std = @import("std");

/// jzbuild ships helpers rather than an artifact, so its own build is a no-op.
pub fn build(b: *std.Build) void {
    _ = b;
}

const app_mod = @import("src/app.zig");
const flags_mod = @import("src/flags.zig");

pub const app = app_mod.app;
pub const AppOptions = app_mod.AppOptions;

pub const strictFlags = flags_mod.strictFlags;
pub const testFlags = flags_mod.testFlags;
