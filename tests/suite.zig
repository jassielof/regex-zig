//! Integration (black-box) tests. PCRE2 and RE2 live in `pcre2.zig` / `re2.zig`.
test {
    _ = @import("pcre2.zig");
    _ = @import("re2.zig");
}
