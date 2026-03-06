//! Regular expressions.
// For some reason, this won't work if I try to use imports in the build.zig file, so I'm just directly importing the zig modules.
pub const pcre2 = @import("pcre2.zig");
pub const re2 = @import("re2.zig");
