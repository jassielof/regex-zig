//! Integration (black-box) tests for pcre2 and re2 modules.
const std = @import("std");
const build_options = @import("build_options");
const pcre2 = @import("pcre2");

const bundle_re2 = build_options.bundle_re2;
const re2 = if (bundle_re2) @import("re2") else struct {};

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
// RE2 integration tests
test "re2: compile valid pattern" {
    if (bundle_re2) {
        var pat = try re2.Pattern.compile("hello");
        defer pat.deinit();
    } else {
        return error.SkipZigTest;
    }
}

test "re2: compile invalid pattern returns error" {
    if (bundle_re2) {
        const r = re2.Pattern.compile("(unclosed");
        try std.testing.expectError(re2.CompileError.InvalidPattern, r);
    } else {
        return error.SkipZigTest;
    }
}

test "re2: match returns correct full range" {
    if (bundle_re2) {
        var pat = try re2.Pattern.compile("hello");
        defer pat.deinit();
        const m = re2.match("hello world", &pat, 0);
        try std.testing.expect(m != null);
        try std.testing.expectEqualStrings(m.?.full(), "hello");
    } else {
        return error.SkipZigTest;
    }
}

test "re2: match with capture groups" {
    if (bundle_re2) {
        var pat = try re2.Pattern.compile("(hel)(lo)");
        defer pat.deinit();
        const m = re2.match("hello", &pat, 0);
        try std.testing.expect(m != null);
        try std.testing.expectEqualStrings(m.?.full(), "hello");
        try std.testing.expectEqualStrings(m.?.group(1), "hel");
        try std.testing.expectEqualStrings(m.?.group(2), "lo");
    } else {
        return error.SkipZigTest;
    }
}

test "re2: no match returns null" {
    if (bundle_re2) {
        var pat = try re2.Pattern.compile("xyz");
        defer pat.deinit();
        const m = re2.match("hello world", &pat, 0);
        try std.testing.expect(m == null);
    } else {
        return error.SkipZigTest;
    }
}

test "re2: search first occurrence" {
    if (bundle_re2) {
        var pat = try re2.Pattern.compile("l+");
        defer pat.deinit();
        const m = re2.search("hello world", &pat);
        try std.testing.expect(m != null);
        try std.testing.expectEqualStrings(m.?.full(), "ll");
    } else {
        return error.SkipZigTest;
    }
}

test "re2: findAll multiple matches" {
    if (bundle_re2) {
        var pat = try re2.Pattern.compile("\\d+");
        defer pat.deinit();
        var matches = try re2.findAll(std.testing.allocator, "a1b22c333", &pat);
        defer std.testing.allocator.free(matches);
        try std.testing.expect(matches.len == 3);
        try std.testing.expectEqualStrings(matches[0].full(), "1");
        try std.testing.expectEqualStrings(matches[1].full(), "22");
        try std.testing.expectEqualStrings(matches[2].full(), "333");
    } else {
        return error.SkipZigTest;
    }
}

test "re2: replace global" {
    if (bundle_re2) {
        var pat = try re2.Pattern.compile("x");
        defer pat.deinit();
        const out = try re2.replace(std.testing.allocator, "axbxc", &pat, "Y", true);
        defer std.testing.allocator.free(out);
        try std.testing.expectEqualStrings(out, "aYbYc");
    } else {
        return error.SkipZigTest;
    }
}

test "re2: replace single" {
    if (bundle_re2) {
        var pat = try re2.Pattern.compile("x");
        defer pat.deinit();
        const out = try re2.replace(std.testing.allocator, "axbxc", &pat, "Y", false);
        defer std.testing.allocator.free(out);
        try std.testing.expectEqualStrings(out, "aYbxc");
    } else {
        return error.SkipZigTest;
    }
}

test "re2: isMatch" {
    if (bundle_re2) {
        var pat = try re2.Pattern.compile("\\d+");
        defer pat.deinit();
        try std.testing.expect(re2.isMatch("a1b", &pat));
        try std.testing.expect(!re2.isMatch("abc", &pat));
    } else {
        return error.SkipZigTest;
    }
}

test "re2: unicode UTF-8" {
    if (bundle_re2) {
        var pat = try re2.Pattern.compile("é");
        defer pat.deinit();
        const m = re2.match("café", &pat, 0);
        try std.testing.expect(m != null);
        try std.testing.expectEqualStrings(m.?.full(), "é");
    } else {
        return error.SkipZigTest;
    }
}
