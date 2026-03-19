//! RE2 integration tests (`zig build tests`).
//!
//! RE2 has **no** PCRE2-style code-unit width or JIT flags: it is UTF-8-oriented and
//! uses a linear-time engine. See `re2.icu_unicode_properties` (`-Dre2-icu`; C++ ICU build not wired yet).
//!
//! **Safety:** RE2 guarantees matching in time linear in the length of the input (see
//! [RE2 docs](https://github.com/google/re2/wiki/Syntax)). Patterns with unbounded
//! nesting may be **rejected at compile time** rather than risking slow matching.
const std = @import("std");
const re2 = @import("re2");

// ----------------------------------------------------------------------------
// Core API

test "re2: compile valid pattern" {
    var pat = try re2.Pattern.compile("hello");
    defer pat.deinit();
}

test "re2: compile invalid pattern returns error" {
    const r = re2.Pattern.compile("(unclosed");
    try std.testing.expectError(re2.CompileError.InvalidPattern, r);
}

test "re2: match returns correct full range" {
    var pat = try re2.Pattern.compile("hello");
    defer pat.deinit();
    const m = re2.match("hello world", &pat, 0);
    try std.testing.expect(m != null);
    try std.testing.expectEqualStrings("hello", m.?.full());
}

test "re2: match with capture groups" {
    var pat = try re2.Pattern.compile("(hel)(lo)");
    defer pat.deinit();
    const m = re2.match("hello", &pat, 0);
    try std.testing.expect(m != null);
    try std.testing.expectEqualStrings("hello", m.?.full());
    try std.testing.expectEqualStrings("hel", m.?.group(1));
    try std.testing.expectEqualStrings("lo", m.?.group(2));
}

test "re2: no match returns null" {
    var pat = try re2.Pattern.compile("xyz");
    defer pat.deinit();
    const m = re2.match("hello world", &pat, 0);
    try std.testing.expect(m == null);
}

test "re2: search first occurrence" {
    var pat = try re2.Pattern.compile("l+");
    defer pat.deinit();
    const m = re2.search("hello world", &pat);
    try std.testing.expect(m != null);
    try std.testing.expectEqualStrings("ll", m.?.full());
}

test "re2: findAll multiple matches" {
    var pat = try re2.Pattern.compile("\\d+");
    defer pat.deinit();
    var matches = try re2.findAll(std.testing.allocator, "a1b22c333", &pat);
    defer std.testing.allocator.free(matches);
    try std.testing.expect(matches.len == 3);
    try std.testing.expectEqualStrings("1", matches[0].full());
    try std.testing.expectEqualStrings("22", matches[1].full());
    try std.testing.expectEqualStrings("333", matches[2].full());
}

test "re2: replace global" {
    var pat = try re2.Pattern.compile("x");
    defer pat.deinit();
    const out = try re2.replace(std.testing.allocator, "axbxc", &pat, "Y", true);
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings(out, "aYbYc");
}

test "re2: replace single" {
    var pat = try re2.Pattern.compile("x");
    defer pat.deinit();
    const out = try re2.replace(std.testing.allocator, "axbxc", &pat, "Y", false);
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings(out, "aYbxc");
}

test "re2: isMatch" {
    var pat = try re2.Pattern.compile("\\d+");
    defer pat.deinit();
    try std.testing.expect(re2.isMatch("a1b", &pat));
    try std.testing.expect(!re2.isMatch("abc", &pat));
}

test "re2: unicode UTF-8" {
    var pat = try re2.Pattern.compile("é");
    defer pat.deinit();
    const m = re2.match("café", &pat, 0);
    try std.testing.expect(m != null);
    try std.testing.expectEqualStrings("é", m.?.full());
}

// ----------------------------------------------------------------------------
// Inline flags

test "re2: caseless via (?i) inline flag" {
    var pat = try re2.Pattern.compile("(?i)hello");
    defer pat.deinit();
    try std.testing.expect(re2.isMatch("HELLO", &pat));
    try std.testing.expect(!re2.isMatch("world", &pat));
}

test "re2: dotall via (?s) inline flag" {
    var pat = try re2.Pattern.compile("(?s)a.b");
    defer pat.deinit();
    try std.testing.expect(re2.isMatch("a\nb", &pat));
    var pat_no_ds = try re2.Pattern.compile("a.b");
    defer pat_no_ds.deinit();
    try std.testing.expect(!re2.isMatch("a\nb", &pat_no_ds));
}

test "re2: multiline via (?m) inline flag" {
    var pat = try re2.Pattern.compile("(?m)^bar");
    defer pat.deinit();
    try std.testing.expect(re2.isMatch("foo\nbar\nbaz", &pat));
    var pat_no_ml = try re2.Pattern.compile("^bar");
    defer pat_no_ml.deinit();
    try std.testing.expect(!re2.isMatch("foo\nbar\nbaz", &pat_no_ml));
}

test "re2: start_offset skips earlier occurrences" {
    var pat = try re2.Pattern.compile("\\d+");
    defer pat.deinit();
    const m1 = re2.match("a123b456", &pat, 0);
    try std.testing.expect(m1 != null);
    try std.testing.expectEqualStrings("123", m1.?.full());

    const m2 = re2.match("a123b456", &pat, 5);
    try std.testing.expect(m2 != null);
    try std.testing.expectEqualStrings("456", m2.?.full());
}

test "re2: groupCount" {
    var pat = try re2.Pattern.compile("(a)(b)(c)");
    defer pat.deinit();
    const m = re2.match("abc", &pat, 0);
    try std.testing.expect(m != null);
    try std.testing.expect(m.?.groupCount() == 3);
}

// ----------------------------------------------------------------------------
// Build / feature flags (reserved for future RE2_USE_ICU wiring)

test "re2: icu_unicode_properties reflects build option (default false)" {
    try std.testing.expect(!re2.icu_unicode_properties);
}

// ----------------------------------------------------------------------------
// Safety: linear time, restricted syntax

test "re2 safety: nested quantifiers compile; engine stays linear-time" {
    // Unlike classical NFA engines, RE2 still accepts some nested quantifiers but
    // matches in time linear in the input size (no exponential backtracking).
    var pat = try re2.Pattern.compile("(a+)+b");
    defer pat.deinit();
    const subject = try std.testing.allocator.alloc(u8, 5000);
    defer std.testing.allocator.free(subject);
    @memset(subject, 'a');
    subject[subject.len - 1] = 'c';
    const t0 = std.time.nanoTimestamp();
    const m = re2.match(subject, &pat, 0);
    const elapsed = std.time.nanoTimestamp() - t0;
    try std.testing.expect(m == null); // …aaaac does not end with b
    try std.testing.expect(elapsed < std.time.ns_per_s);
}

test "re2 safety: backreference without group is invalid" {
    const r = re2.Pattern.compile("\\1");
    try std.testing.expectError(re2.CompileError.InvalidPattern, r);
}

test "re2 safety: long subject with safe pattern completes quickly" {
    // A pattern RE2 accepts should match in time linear in |subject|.
    var pat = try re2.Pattern.compile("a+b");
    defer pat.deinit();
    const n: usize = 50_000;
    const subject = try std.testing.allocator.alloc(u8, n + 1);
    defer std.testing.allocator.free(subject);
    @memset(subject[0..n], 'a');
    subject[n] = 'b';

    const t0 = std.time.nanoTimestamp();
    const m = re2.match(subject, &pat, 0);
    const elapsed_ns = std.time.nanoTimestamp() - t0;

    try std.testing.expect(m != null);
    try std.testing.expectEqualStrings(subject, m.?.full());
    // Generous bound: linear engine should finish in well under 1s on CI.
    try std.testing.expect(elapsed_ns < std.time.ns_per_s);
}

test "re2 safety: exponential-style alternation still compiles; match bounded" {
    // RE2 allows (a|b)* on a long string — should remain fast (linear in input size).
    var pat = try re2.Pattern.compile("(a|b)*c");
    defer pat.deinit();
    var buf: [4096]u8 = undefined;
    @memset(buf[0 .. buf.len - 1], 'a');
    buf[buf.len - 1] = 'c';
    const t0 = std.time.nanoTimestamp();
    const m = re2.match(&buf, &pat, 0);
    const elapsed = std.time.nanoTimestamp() - t0;
    try std.testing.expect(m != null);
    try std.testing.expect(elapsed < std.time.ns_per_s);
}
