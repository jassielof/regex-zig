//! Integration (black-box) tests for the pcre2 module.
const std = @import("std");
const pcre2 = @import("pcre2");

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
