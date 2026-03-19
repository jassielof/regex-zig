//! PCRE2 integration tests (`zig build tests`).
//!
//! **Code unit width:** this binary is built for one width (`-Dpcre2-width=8|16|32`).
//! Run CI with three separate commands to cover all widths.
//!
//! **JIT:** use `-Dpcre2-jit=true` and `-Dpcre2-jit=false` for coverage.
const std = @import("std");
const pcre2 = @import("pcre2");

fn expectCharsAsUtf8(expected_ascii: []const u8, actual: []const pcre2.Char) !void {
    if (pcre2.Char == u8) {
        try std.testing.expectEqualStrings(expected_ascii, actual);
    } else {
        try std.testing.expectEqual(expected_ascii.len, actual.len);
        for (expected_ascii, actual) |e, a| {
            try std.testing.expectEqual(@as(pcre2.Char, e), a);
        }
    }
}

// ----------------------------------------------------------------------------
// Core API

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
    const m = try pcre2.match("hello world", &pat, 0);
    try std.testing.expect(m != null);
    try expectCharsAsUtf8("hello", m.?.full());
}

test "match: with capture groups" {
    var pat = try pcre2.Pattern.compile("(hel)(lo)", .{});
    defer pat.deinit();
    const m = try pcre2.match("hello", &pat, 0);
    try std.testing.expect(m != null);
    try expectCharsAsUtf8("hello", m.?.full());
    try expectCharsAsUtf8("hel", m.?.group(1));
    try expectCharsAsUtf8("lo", m.?.group(2));
}

test "match: no match returns null" {
    var pat = try pcre2.Pattern.compile("xyz", .{});
    defer pat.deinit();
    const m = try pcre2.match("hello world", &pat, 0);
    try std.testing.expect(m == null);
}

test "search: first occurrence" {
    var pat = try pcre2.Pattern.compile("l+", .{});
    defer pat.deinit();
    const m = try pcre2.search("hello world", &pat);
    try std.testing.expect(m != null);
    try expectCharsAsUtf8("ll", m.?.full());
}

test "findAll: multiple non-overlapping matches" {
    var pat = try pcre2.Pattern.compile("\\d+", .{});
    defer pat.deinit();
    var matches = try pcre2.findAll(std.testing.allocator, "a1b22c333", &pat);
    defer std.testing.allocator.free(matches);
    try std.testing.expect(matches.len == 3);
    try expectCharsAsUtf8("1", matches[0].full());
    try expectCharsAsUtf8("22", matches[1].full());
    try expectCharsAsUtf8("333", matches[2].full());
}

test "replace: global" {
    var pat = try pcre2.Pattern.compile("x", .{});
    defer pat.deinit();
    const out = try pcre2.replace(std.testing.allocator, "axbxc", &pat, "Y", true);
    defer std.testing.allocator.free(out);
    try expectCharsAsUtf8("aYbYc", out);
}

test "replace: single replacement" {
    var pat = try pcre2.Pattern.compile("x", .{});
    defer pat.deinit();
    const out = try pcre2.replace(std.testing.allocator, "axbxc", &pat, "Y", false);
    defer std.testing.allocator.free(out);
    try expectCharsAsUtf8("aYbxc", out);
}

test "isMatch: true when pattern matches" {
    var pat = try pcre2.Pattern.compile("\\d+", .{});
    defer pat.deinit();
    try std.testing.expect(try pcre2.isMatch("a1b", &pat));
}

test "isMatch: false when pattern does not match" {
    var pat = try pcre2.Pattern.compile("\\d+", .{});
    defer pat.deinit();
    try std.testing.expect(!try pcre2.isMatch("abc", &pat));
}

test "unicode: UTF-8 subject and pattern (width 8 UTF-8 mode)" {
    if (pcre2.Char != u8) return error.SkipZigTest;
    var pat = try pcre2.Pattern.compile("é", .{});
    defer pat.deinit();
    const m = try pcre2.match("café", &pat, 0);
    try std.testing.expect(m != null);
    try expectCharsAsUtf8("é", m.?.full());
}

// ----------------------------------------------------------------------------
// JIT

test "jit: Pattern.jit reflects jit_enabled when no limits" {
    var pat = try pcre2.Pattern.compile("\\d+", .{});
    defer pat.deinit();
    try std.testing.expect(pat.jit == pcre2.jit_enabled);
}

test "jit: JIT disabled when match limits are set" {
    var pat = try pcre2.Pattern.compile("\\d+", .{ .limits = .{ .match_limit = 9999 } });
    defer pat.deinit();
    try std.testing.expect(!pat.jit);
}

test "jit: match produces correct results" {
    var pat = try pcre2.Pattern.compile("(\\w+)@(\\w+)", .{});
    defer pat.deinit();
    const m = try pcre2.match("send to user@host please", &pat, 0);
    try std.testing.expect(m != null);
    try expectCharsAsUtf8("user@host", m.?.full());
    try expectCharsAsUtf8("user", m.?.group(1));
    try expectCharsAsUtf8("host", m.?.group(2));
}

test "jit: findAll produces correct results" {
    var pat = try pcre2.Pattern.compile("\\d+", .{});
    defer pat.deinit();
    const matches = try pcre2.findAll(std.testing.allocator, "x1y22z333", &pat);
    defer std.testing.allocator.free(matches);
    try std.testing.expect(matches.len == 3);
}

test "jit: replace works correctly" {
    var pat = try pcre2.Pattern.compile("\\d+", .{});
    defer pat.deinit();
    const out = try pcre2.replace(std.testing.allocator, "a1b22c333", &pat, "N", true);
    defer std.testing.allocator.free(out);
    try expectCharsAsUtf8("aNbNcN", out);
}

// ----------------------------------------------------------------------------
// Code unit width (per-build)

test "width: configured_code_unit_width matches Char" {
    switch (pcre2.configured_code_unit_width) {
        .@"8" => try std.testing.expect(pcre2.Char == u8),
        .@"16" => try std.testing.expect(pcre2.Char == u16),
        .@"32" => try std.testing.expect(pcre2.Char == u32),
    }
}

test "width 8: ASCII compile and match" {
    if (pcre2.Char != u8) return error.SkipZigTest;
    var pat = try pcre2.Pattern.compile("ab", .{});
    defer pat.deinit();
    const m = try pcre2.match("zabz", &pat, 0);
    try std.testing.expect(m != null);
    try std.testing.expectEqualStrings("ab", m.?.full());
}

test "width 16: ASCII as UTF-16 code units" {
    if (pcre2.Char != u16) return error.SkipZigTest;
    const pattern = [_]pcre2.Char{ 'a', 'b' };
    var pat = try pcre2.Pattern.compile(&pattern, .{});
    defer pat.deinit();
    const subject = [_]pcre2.Char{ 'z', 'a', 'b', 'z' };
    const m = try pcre2.match(&subject, &pat, 0);
    try std.testing.expect(m != null);
    try std.testing.expectEqual(@as(usize, 2), m.?.full().len);
    try std.testing.expectEqual(@as(pcre2.Char, 'a'), m.?.full()[0]);
    try std.testing.expectEqual(@as(pcre2.Char, 'b'), m.?.full()[1]);
}

test "width 32: ASCII as UTF-32 code units" {
    if (pcre2.Char != u32) return error.SkipZigTest;
    const pattern = [_]pcre2.Char{ 'x', 'y' };
    var pat = try pcre2.Pattern.compile(&pattern, .{});
    defer pat.deinit();
    const subject = [_]pcre2.Char{ '!', 'x', 'y', '!' };
    const m = try pcre2.match(&subject, &pat, 0);
    try std.testing.expect(m != null);
    try std.testing.expectEqual(@as(usize, 2), m.?.full().len);
}

test "width: compileLiteral with current Char width" {
    const dot: []const pcre2.Char = switch (pcre2.Char) {
        u8 => ".",
        u16 => &[_]pcre2.Char{ '.' },
        u32 => &[_]pcre2.Char{ '.' },
        else => @compileError("Char"),
    };
    const hello: []const pcre2.Char = switch (pcre2.Char) {
        u8 => "hello",
        u16 => &[_]pcre2.Char{ 'h', 'e', 'l', 'l', 'o' },
        u32 => &[_]pcre2.Char{ 'h', 'e', 'l', 'l', 'o' },
        else => @compileError("Char"),
    };
    const literal_pat = try std.mem.concat(std.testing.allocator, pcre2.Char, &.{ hello, dot, hello });
    defer std.testing.allocator.free(literal_pat);
    var pat = try pcre2.Pattern.compileLiteral(literal_pat);
    defer pat.deinit();

    const ok_subj = try std.mem.concat(std.testing.allocator, pcre2.Char, &.{ hello, dot, hello });
    defer std.testing.allocator.free(ok_subj);
    try std.testing.expect(try pcre2.isMatch(ok_subj, &pat));

    const bad_subj = try std.mem.concat(std.testing.allocator, pcre2.Char, &.{ hello, &[_]pcre2.Char{'X'}, hello });
    defer std.testing.allocator.free(bad_subj);
    try std.testing.expect(!try pcre2.isMatch(bad_subj, &pat));
}

// ----------------------------------------------------------------------------
// CompileOptions

test "caseless: matches regardless of case" {
    var pat = try pcre2.Pattern.compile("hello", .{ .caseless = true });
    defer pat.deinit();
    try std.testing.expect(try pcre2.isMatch("HELLO", &pat));
    try std.testing.expect(try pcre2.isMatch("Hello", &pat));
    try std.testing.expect(!try pcre2.isMatch("world", &pat));
}

test "multiline: ^ and $ anchor to line boundaries" {
    var pat = try pcre2.Pattern.compile("^bar", .{ .multiline = true });
    defer pat.deinit();
    try std.testing.expect(try pcre2.isMatch("foo\nbar\nbaz", &pat));
    var pat_no_ml = try pcre2.Pattern.compile("^bar", .{});
    defer pat_no_ml.deinit();
    try std.testing.expect(!try pcre2.isMatch("foo\nbar\nbaz", &pat_no_ml));
}

test "dotall: dot matches newline" {
    var pat = try pcre2.Pattern.compile("a.b", .{ .dotall = true });
    defer pat.deinit();
    try std.testing.expect(try pcre2.isMatch("a\nb", &pat));
    var pat_no_ds = try pcre2.Pattern.compile("a.b", .{});
    defer pat_no_ds.deinit();
    try std.testing.expect(!try pcre2.isMatch("a\nb", &pat_no_ds));
}

// ----------------------------------------------------------------------------
// start_offset, groups

test "match: start_offset skips earlier occurrences" {
    var pat = try pcre2.Pattern.compile("\\d+", .{});
    defer pat.deinit();
    const m1 = try pcre2.match("a123b456", &pat, 0);
    try std.testing.expect(m1 != null);
    try expectCharsAsUtf8("123", m1.?.full());

    const m2 = try pcre2.match("a123b456", &pat, 5);
    try std.testing.expect(m2 != null);
    try expectCharsAsUtf8("456", m2.?.full());
}

test "match: groupCount returns number of capture groups" {
    var pat = try pcre2.Pattern.compile("(a)(b)(c)", .{});
    defer pat.deinit();
    const m = try pcre2.match("abc", &pat, 0);
    try std.testing.expect(m != null);
    try std.testing.expect(m.?.groupCount() == 3);
}

test "match: optional group that did not participate is empty" {
    var pat = try pcre2.Pattern.compile("(a)|(b)", .{});
    defer pat.deinit();
    const m = try pcre2.match("a", &pat, 0);
    try std.testing.expect(m != null);
    try expectCharsAsUtf8("a", m.?.group(1));
    try std.testing.expectEqual(@as(usize, 0), m.?.group(2).len);
}

// ----------------------------------------------------------------------------
// Match limits (catastrophic backtracking mitigation)

test "safety: match_limit exceeded on pathological pattern" {
    // Same scenario as PCRE2 testdata `testinput17` / `/(a+)*zz/` + `aaaaaaaaaaaaaz`
    // with `match_limit=3000` → error -47 (match limit exceeded).
    const pat_ascii = "(a+)*zz";
    const subj_ascii = "aaaaaaaaaaaaaz";
    const pattern: []const pcre2.Char = switch (pcre2.Char) {
        u8 => pat_ascii,
        u16 => &[_]pcre2.Char{ '(', 'a', '+', ')', '*', 'z', 'z' },
        u32 => &[_]pcre2.Char{ '(', 'a', '+', ')', '*', 'z', 'z' },
        else => @compileError("Char"),
    };
    const subject = try std.testing.allocator.alloc(pcre2.Char, subj_ascii.len);
    defer std.testing.allocator.free(subject);
    for (subj_ascii, 0..) |c, i| subject[i] = @as(pcre2.Char, c);

    var pat = try pcre2.Pattern.compile(pattern, .{ .limits = .{ .match_limit = 3000 } });
    defer pat.deinit();
    const r = pcre2.match(subject, &pat, 0);
    try std.testing.expectError(error.MatchLimitExceeded, r);
}

test "safety: depth_limit exceeded on deep nesting" {
    // 30 nested groups; depth limit 8 should trip during match attempt.
    var pat = try pcre2.Pattern.compile(
        "((((((((((((((((((((((((((((((a))))))))))))))))))))))))))))))",
        .{ .limits = .{ .depth_limit = 8 } },
    );
    defer pat.deinit();
    const r = pcre2.match("a", &pat, 0);
    try std.testing.expectError(error.DepthLimitExceeded, r);
}

test "safety: normal match succeeds with generous limits" {
    var pat = try pcre2.Pattern.compile("a+b", .{ .limits = .{ .match_limit = 100000 } });
    defer pat.deinit();
    const m = try pcre2.match("aaab", &pat, 0);
    try std.testing.expect(m != null);
    try expectCharsAsUtf8("aaab", m.?.full());
}
