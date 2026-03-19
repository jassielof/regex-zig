//! Google RE2 bindings: convenient, Python `re` / C# `Regex`-style API over RE2.
//!
//! RE2 is built from the `modules/re2` submodule via CMake (requires CMake and Abseil).
//! Zero-copy where possible; allocator only for replace and findAll.
const std = @import("std");

const re2c = @cImport({
    @cInclude("re2_ffi.h");
});

const RE2_UNSET = std.math.maxInt(usize);

// ----------------------------------------------------------------------------
// Compile error (RE2 has no error set at compile in our minimal API; we use ok())
pub const CompileError = error{
    InvalidPattern,
};

// ----------------------------------------------------------------------------
// Pattern (owns compiled RE2). Compile with `Pattern.compile("...")`, then `deinit`.
pub const Pattern = struct {
    ptr: *re2c.re2_regexp,

    const Self = @This();

    /// Release the compiled pattern.
    pub fn deinit(self: *Self) void {
        re2c.re2_delete(self.ptr);
        self.* = undefined;
    }

    /// Compile a pattern. Returns error if the pattern is invalid.
    pub fn compile(pattern: []const u8) CompileError!Self {
        const ptr = re2c.re2_new(pattern.ptr, pattern.len) orelse return CompileError.InvalidPattern;
        if (re2c.re2_ok(ptr) == 0) {
            re2c.re2_delete(ptr);
            return CompileError.InvalidPattern;
        }
        return .{ .ptr = ptr };
    }

    /// Compile a literal string. Same as compile for this minimal API.
    pub fn compileLiteral(pattern: []const u8) CompileError!Self {
        return compile(pattern);
    }
};

/// Error message for the last compile error (if any). Empty if pattern is ok.
pub fn getErrorMessage(pat: *const Pattern) []const u8 {
    const s = re2c.re2_error_string(pat.ptr);
    if (s == null) return "";
    return std.mem.span(s);
}

test "Pattern.compile" {
    var pat = try Pattern.compile("hello");
    defer pat.deinit();
    try std.testing.expect(pat.ptr != null);
}

// ----------------------------------------------------------------------------
// Match (slices into subject; no allocator). Use `.full()` and `.group(i)`.
const MAX_GROUPS = 32;

pub const Match = struct {
    subject: []const u8,
    pairs: [MAX_GROUPS][2]usize,
    n: u32,

    /// Full match slice (group 0).
    pub fn full(self: *const Match) []const u8 {
        if (self.n == 0) return self.subject[0..0];
        const s = self.pairs[0][0];
        const e = self.pairs[0][1];
        if (s == RE2_UNSET or e == RE2_UNSET) return self.subject[0..0];
        return self.subject[s..e];
    }

    /// Capture group by index (0 = full match, 1 = first group). Returns empty if unset.
    pub fn group(self: *const Match, index: u32) []const u8 {
        if (index >= self.n) return self.subject[0..0];
        const s = self.pairs[index][0];
        const e = self.pairs[index][1];
        if (s == RE2_UNSET or e == RE2_UNSET) return self.subject[0..0];
        return self.subject[s..e];
    }

    pub fn groupCount(self: *const Match) u32 {
        if (self.n <= 1) return 0;
        return self.n - 1;
    }
};

fn matchInternal(subject: []const u8, pat: *const Pattern, start_offset: usize, anchor: c_int) ?Match {
    var match_begin: [MAX_GROUPS]usize = undefined;
    var match_end: [MAX_GROUPS]usize = undefined;
    const rc = re2c.re2_match(
        pat.ptr,
        subject.ptr,
        subject.len,
        start_offset,
        subject.len,
        anchor,
        &match_begin,
        &match_end,
        MAX_GROUPS,
    );
    if (rc != 1) return null;
    var n: u32 = 0;
    while (n < MAX_GROUPS and match_begin[n] != RE2_UNSET) : (n += 1) {}
    if (n == 0) n = 1;
    var m: Match = .{
        .subject = subject,
        .pairs = undefined,
        .n = n,
    };
    for (0..n) |i| {
        m.pairs[i][0] = match_begin[i];
        m.pairs[i][1] = match_end[i];
    }
    return m;
}

/// Single match in `subject` starting at `start_offset`. Unanchored. Returns null if no match.
pub fn match(subject: []const u8, pat: *const Pattern, start_offset: usize) ?Match {
    return matchInternal(subject, pat, start_offset, 0);
}

test match {
    var pat = try Pattern.compile("(hello)|(world)");
    defer pat.deinit();
    const m = match("hello world", &pat, 0);
    try std.testing.expect(m != null);
    try std.testing.expectEqualStrings(m.?.full(), "hello");
    try std.testing.expectEqualStrings(m.?.group(1), "hello");
}

/// First occurrence of pattern in subject.
pub fn search(subject: []const u8, pat: *const Pattern) ?Match {
    return match(subject, pat, 0);
}

/// Returns true if pattern matches anywhere in subject.
pub fn isMatch(subject: []const u8, pat: *const Pattern) bool {
    return match(subject, pat, 0) != null;
}

test isMatch {
    var pat = try Pattern.compile("\\d+");
    defer pat.deinit();
    try std.testing.expect(isMatch("a1b", &pat));
    try std.testing.expect(!isMatch("abc", &pat));
}

// ----------------------------------------------------------------------------
// Find all non-overlapping matches
pub fn findAll(allocator: std.mem.Allocator, subject: []const u8, pat: *const Pattern) ![]Match {
    var list = std.ArrayList(Match).empty;
    errdefer list.deinit(allocator);
    var start: usize = 0;
    while (start <= subject.len) {
        const m = match(subject, pat, start) orelse break;
        try list.append(allocator, m);
        const full = m.full();
        if (full.len == 0) break;
        start = m.pairs[0][1];
    }
    return try list.toOwnedSlice(allocator);
}

test findAll {
    var pat = try Pattern.compile("\\d+");
    defer pat.deinit();
    var matches = try findAll(std.testing.allocator, "a1b22c", &pat);
    defer std.testing.allocator.free(matches);
    try std.testing.expect(matches.len == 2);
    try std.testing.expectEqualStrings(matches[0].full(), "1");
    try std.testing.expectEqualStrings(matches[1].full(), "22");
}

// ----------------------------------------------------------------------------
// Replace: allocator for output
pub fn replace(
    allocator: std.mem.Allocator,
    subject: []const u8,
    pat: *const Pattern,
    replacement: []const u8,
    global: bool,
) ![]const u8 {
    var out_len: usize = 4096;
    var buf = try allocator.alloc(u8, out_len);
    defer allocator.free(buf);
    const rc = re2c.re2_replace(
        pat.ptr,
        subject.ptr,
        subject.len,
        replacement.ptr,
        replacement.len,
        if (global) 1 else 0,
        buf.ptr,
        &out_len,
    );
    if (rc == -1) {
        allocator.free(buf);
        buf = try allocator.alloc(u8, out_len);
        const rc2 = re2c.re2_replace(
            pat.ptr,
            subject.ptr,
            subject.len,
            replacement.ptr,
            replacement.len,
            if (global) 1 else 0,
            buf.ptr,
            &out_len,
        );
        if (rc2 != 1) return error.ReplaceFailed;
        return try allocator.dupe(u8, buf[0..out_len]);
    }
    if (rc != 1) return error.ReplaceFailed;
    return try allocator.dupe(u8, buf[0..out_len]);
}

test replace {
    var pat = try Pattern.compile("x");
    defer pat.deinit();
    const out = try replace(std.testing.allocator, "axbxc", &pat, "Y", true);
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings(out, "aYbYc");
}
