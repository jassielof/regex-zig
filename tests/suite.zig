//! Integration (black-box) tests for pcre2 and re2 modules.
const std = @import("std");
const pcre2 = @import("pcre2");
const re2 = @import("re2");

// ----------------------------------------------------------------------------
// PCRE2 tests

test "compile: valid pattern" {
    var pat = try pcre2.Pattern.compile("hello", .{});
    defer pat.deinit();
}

test "compile: invalid pattern returns error" {
    const r = pcre2.Pattern.compile("(unclosed", .{});
    try std.testing.expectError(pcre2.CompileError.InvalidPattern, r);
}

test "match: returns match with correct full range" {
    var pat = try pcre2.Pattern.compile("hello", .{});
    defer pat.deinit();
    const m = pcre2.match("hello world", &pat, 0);
    try std.testing.expect(m != null);
    try std.testing.expectEqualStrings(m.?.full(), "hello");
}

test "match: with capture groups" {
    var pat = try pcre2.Pattern.compile("(hel)(lo)", .{});
    defer pat.deinit();
    const m = pcre2.match("hello", &pat, 0);
    try std.testing.expect(m != null);
    try std.testing.expectEqualStrings(m.?.full(), "hello");
    try std.testing.expectEqualStrings(m.?.group(1), "hel");
    try std.testing.expectEqualStrings(m.?.group(2), "lo");
}

test "match: no match returns null" {
    var pat = try pcre2.Pattern.compile("xyz", .{});
    defer pat.deinit();
    const m = pcre2.match("hello world", &pat, 0);
    try std.testing.expect(m == null);
}

test "search: first occurrence" {
    var pat = try pcre2.Pattern.compile("l+", .{});
    defer pat.deinit();
    const m = pcre2.search("hello world", &pat);
    try std.testing.expect(m != null);
    try std.testing.expectEqualStrings(m.?.full(), "ll");
}

test "findAll: multiple non-overlapping matches" {
    var pat = try pcre2.Pattern.compile("\\d+", .{});
    defer pat.deinit();
    var matches = try pcre2.findAll(std.testing.allocator, "a1b22c333", &pat);
    defer std.testing.allocator.free(matches);
    try std.testing.expect(matches.len == 3);
    try std.testing.expectEqualStrings(matches[0].full(), "1");
    try std.testing.expectEqualStrings(matches[1].full(), "22");
    try std.testing.expectEqualStrings(matches[2].full(), "333");
}

test "replace: global" {
    var pat = try pcre2.Pattern.compile("x", .{});
    defer pat.deinit();
    const out = try pcre2.replace(std.testing.allocator, "axbxc", &pat, "Y", true);
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings(out, "aYbYc");
}

test "replace: single replacement" {
    var pat = try pcre2.Pattern.compile("x", .{});
    defer pat.deinit();
    const out = try pcre2.replace(std.testing.allocator, "axbxc", &pat, "Y", false);
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings(out, "aYbxc");
}

test "isMatch: true when pattern matches" {
    var pat = try pcre2.Pattern.compile("\\d+", .{});
    defer pat.deinit();
    try std.testing.expect(pcre2.isMatch("a1b", &pat));
}

test "isMatch: false when pattern does not match" {
    var pat = try pcre2.Pattern.compile("\\d+", .{});
    defer pat.deinit();
    try std.testing.expect(!pcre2.isMatch("abc", &pat));
}

test "unicode: UTF-8 subject and pattern" {
    var pat = try pcre2.Pattern.compile("é", .{});
    defer pat.deinit();
    const m = pcre2.match("café", &pat, 0);
    try std.testing.expect(m != null);
    try std.testing.expectEqualStrings(m.?.full(), "é");
}

// ----------------------------------------------------------------------------
// PCRE2 JIT tests

test "jit: Pattern.jit reflects jit_enabled build option" {
    var pat = try pcre2.Pattern.compile("\\d+", .{});
    defer pat.deinit();
    // When built with -Dpcre2-jit=true every successfully compiled pattern
    // should have JIT ready; when built without JIT it must be false.
    try std.testing.expect(pat.jit == pcre2.jit_enabled);
}

test "jit: match produces correct results" {
    var pat = try pcre2.Pattern.compile("(\\w+)@(\\w+)", .{});
    defer pat.deinit();
    const m = pcre2.match("send to user@host please", &pat, 0);
    try std.testing.expect(m != null);
    try std.testing.expectEqualStrings(m.?.full(), "user@host");
    try std.testing.expectEqualStrings(m.?.group(1), "user");
    try std.testing.expectEqualStrings(m.?.group(2), "host");
}

test "jit: findAll produces correct results" {
    var pat = try pcre2.Pattern.compile("\\d+", .{});
    defer pat.deinit();
    var matches = try pcre2.findAll(std.testing.allocator, "x1y22z333", &pat);
    defer std.testing.allocator.free(matches);
    try std.testing.expect(matches.len == 3);
    try std.testing.expectEqualStrings(matches[0].full(), "1");
    try std.testing.expectEqualStrings(matches[1].full(), "22");
    try std.testing.expectEqualStrings(matches[2].full(), "333");
}

test "jit: replace works correctly" {
    var pat = try pcre2.Pattern.compile("\\d+", .{});
    defer pat.deinit();
    const out = try pcre2.replace(std.testing.allocator, "a1b22c333", &pat, "N", true);
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings(out, "aNbNcN");
}

// ----------------------------------------------------------------------------
// PCRE2 code-unit-width tests

test "width: Char type is u8 for default 8-bit build" {
    // The default build uses width=8; Char must be u8.
    try std.testing.expect(pcre2.Char == u8);
}

test "width: compileLiteral works with current Char type" {
    var pat = try pcre2.Pattern.compileLiteral("hello.world");
    defer pat.deinit();
    // Literal flag: the dot is not a metacharacter.
    try std.testing.expect(pcre2.isMatch("hello.world", &pat));
    try std.testing.expect(!pcre2.isMatch("helloXworld", &pat));
}

// ----------------------------------------------------------------------------
// PCRE2 CompileOptions tests

test "caseless: matches regardless of case" {
    var pat = try pcre2.Pattern.compile("hello", .{ .caseless = true });
    defer pat.deinit();
    try std.testing.expect(pcre2.isMatch("HELLO", &pat));
    try std.testing.expect(pcre2.isMatch("Hello", &pat));
    try std.testing.expect(pcre2.isMatch("hElLo", &pat));
    try std.testing.expect(!pcre2.isMatch("world", &pat));
}

test "multiline: ^ and $ anchor to line boundaries" {
    var pat = try pcre2.Pattern.compile("^bar", .{ .multiline = true });
    defer pat.deinit();
    // "bar" starts a new line so ^ should match there.
    try std.testing.expect(pcre2.isMatch("foo\nbar\nbaz", &pat));
    // Without multiline the same subject would not match.
    var pat_no_ml = try pcre2.Pattern.compile("^bar", .{});
    defer pat_no_ml.deinit();
    try std.testing.expect(!pcre2.isMatch("foo\nbar\nbaz", &pat_no_ml));
}

test "dotall: dot matches newline" {
    var pat = try pcre2.Pattern.compile("a.b", .{ .dotall = true });
    defer pat.deinit();
    try std.testing.expect(pcre2.isMatch("a\nb", &pat));
    // Without dotall the dot does not cross a newline.
    var pat_no_ds = try pcre2.Pattern.compile("a.b", .{});
    defer pat_no_ds.deinit();
    try std.testing.expect(!pcre2.isMatch("a\nb", &pat_no_ds));
}

// ----------------------------------------------------------------------------
// PCRE2 match start_offset and groupCount tests

test "match: start_offset skips earlier occurrences" {
    var pat = try pcre2.Pattern.compile("\\d+", .{});
    defer pat.deinit();
    // First match is "123" at offset 1; skip past it by starting at offset 5.
    const m1 = pcre2.match("a123b456", &pat, 0);
    try std.testing.expect(m1 != null);
    try std.testing.expectEqualStrings(m1.?.full(), "123");

    const m2 = pcre2.match("a123b456", &pat, 5);
    try std.testing.expect(m2 != null);
    try std.testing.expectEqualStrings(m2.?.full(), "456");
}

test "match: groupCount returns number of capture groups" {
    var pat = try pcre2.Pattern.compile("(a)(b)(c)", .{});
    defer pat.deinit();
    const m = pcre2.match("abc", &pat, 0);
    try std.testing.expect(m != null);
    try std.testing.expect(m.?.groupCount() == 3);
    try std.testing.expectEqualStrings(m.?.group(1), "a");
    try std.testing.expectEqualStrings(m.?.group(2), "b");
    try std.testing.expectEqualStrings(m.?.group(3), "c");
}

test "match: optional group that did not participate is empty" {
    var pat = try pcre2.Pattern.compile("(a)|(b)", .{});
    defer pat.deinit();
    const m = pcre2.match("a", &pat, 0);
    try std.testing.expect(m != null);
    try std.testing.expectEqualStrings(m.?.group(1), "a");
    try std.testing.expectEqualStrings(m.?.group(2), ""); // unset group
}

// ----------------------------------------------------------------------------
// RE2 tests

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
    try std.testing.expectEqualStrings(m.?.full(), "hello");
}

test "re2: match with capture groups" {
    var pat = try re2.Pattern.compile("(hel)(lo)");
    defer pat.deinit();
    const m = re2.match("hello", &pat, 0);
    try std.testing.expect(m != null);
    try std.testing.expectEqualStrings(m.?.full(), "hello");
    try std.testing.expectEqualStrings(m.?.group(1), "hel");
    try std.testing.expectEqualStrings(m.?.group(2), "lo");
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
    try std.testing.expectEqualStrings(m.?.full(), "ll");
}

test "re2: findAll multiple matches" {
    var pat = try re2.Pattern.compile("\\d+");
    defer pat.deinit();
    var matches = try re2.findAll(std.testing.allocator, "a1b22c333", &pat);
    defer std.testing.allocator.free(matches);
    try std.testing.expect(matches.len == 3);
    try std.testing.expectEqualStrings(matches[0].full(), "1");
    try std.testing.expectEqualStrings(matches[1].full(), "22");
    try std.testing.expectEqualStrings(matches[2].full(), "333");
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
    try std.testing.expectEqualStrings(m.?.full(), "é");
}

// ----------------------------------------------------------------------------
// RE2 inline-flag and advanced tests

test "re2: caseless via (?i) inline flag" {
    var pat = try re2.Pattern.compile("(?i)hello");
    defer pat.deinit();
    try std.testing.expect(re2.isMatch("HELLO", &pat));
    try std.testing.expect(re2.isMatch("Hello", &pat));
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
    try std.testing.expectEqualStrings(m1.?.full(), "123");

    const m2 = re2.match("a123b456", &pat, 5);
    try std.testing.expect(m2 != null);
    try std.testing.expectEqualStrings(m2.?.full(), "456");
}

test "re2: groupCount and named groups" {
    var pat = try re2.Pattern.compile("(a)(b)(c)");
    defer pat.deinit();
    const m = re2.match("abc", &pat, 0);
    try std.testing.expect(m != null);
    try std.testing.expect(m.?.groupCount() == 3);
    try std.testing.expectEqualStrings(m.?.group(1), "a");
    try std.testing.expectEqualStrings(m.?.group(2), "b");
    try std.testing.expectEqualStrings(m.?.group(3), "c");
}
