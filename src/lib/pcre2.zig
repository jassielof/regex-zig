//! PCRE2 bindings: convenient, Python `re` / C# `Regex`-style API over PCRE2.
//! Code unit width is configurable at build time (8, 16, or 32).
//! Zero-copy where possible; allocator only when needed (e.g. replace, findAll).
const std = @import("std");

const pcre2_options = @import("pcre2_options");

const pcre2c = @cImport({
    @cDefine("PCRE2_CODE_UNIT_WIDTH", switch (pcre2_options.code_unit_width) {
        .@"8" => "8",
        .@"16" => "16",
        .@"32" => "32",
    });

    @cInclude("pcre2.h");
});

fn pcre2Type(comptime base: []const u8) type {
    const suffix = @tagName(pcre2_options.code_unit_width);
    return @field(pcre2c, base ++ "_" ++ suffix);
}

// ----------------------------------------------------------------------------
// C constants we need (8-bit build)
const PCRE2_ZERO_TERMINATED = pcre2c.PCRE2_ZERO_TERMINATED;
// C macro (~(PCRE2_SIZE)0) not translatable by Zig; use maxInt(usize) for "unset" offsets
const PCRE2_UNSET_val = std.math.maxInt(usize);
const PCRE2_ERROR_NOMATCH = pcre2c.PCRE2_ERROR_NOMATCH;
const PCRE2_ERROR_NOMEMORY = pcre2c.PCRE2_ERROR_NOMEMORY;
const PCRE2_SUBSTITUTE_GLOBAL = pcre2c.PCRE2_SUBSTITUTE_GLOBAL;
const PCRE2_CASELESS = pcre2c.PCRE2_CASELESS;
const PCRE2_MULTILINE = pcre2c.PCRE2_MULTILINE;
const PCRE2_DOTALL = pcre2c.PCRE2_DOTALL;
const PCRE2_UTF = pcre2c.PCRE2_UTF;
const PCRE2_LITERAL = pcre2c.PCRE2_LITERAL;

// ----------------------------------------------------------------------------
// Compile options (Zig-friendly)
pub const CompileOptions = struct {
    caseless: bool = false,
    multiline: bool = false,
    dotall: bool = false,
    utf: bool = true,
    literal: bool = false,

    fn toPcre2Flags(opts: CompileOptions) u32 {
        var f: u32 = 0;
        if (opts.caseless) f |= PCRE2_CASELESS;
        if (opts.multiline) f |= PCRE2_MULTILINE;
        if (opts.dotall) f |= PCRE2_DOTALL;
        if (opts.utf) f |= PCRE2_UTF;
        if (opts.literal) f |= PCRE2_LITERAL;
        return f;
    }
};

// ----------------------------------------------------------------------------
// Compile error
pub const CompileError = error{
    InvalidPattern,
    PatternTooLarge,
    NestLimit,
    HeapFailed,
    /// Use `getErrorMessage` for details; offset is in pattern.
    Other,
};

/// Returns a human-readable message for a PCRE2 error code.
/// Caller provides buffer; returns slice of buffer that was written.
pub fn getErrorMessage(code: c_int, buffer: []u8) []const u8 {
    if (buffer.len == 0) return "";
    const n = pcre2c.pcre2_get_error_message_8(code, buffer.ptr, buffer.len);
    if (n <= 0) return "";
    return buffer[0..@min(@as(usize, @intCast(n)), buffer.len)];
}

// ----------------------------------------------------------------------------
// Pattern (owns compiled code and optional match_data for reuse)
pub const Pattern = struct {
    code: *pcre2c.pcre2_code_8,
    match_data: ?*pcre2c.pcre2_match_data_8,

    const Self = @This();

    /// Release compiled code and any cached match_data.
    pub fn deinit(self: *Self) void {
        if (self.match_data) |md| {
            pcre2c.pcre2_match_data_free_8(md);
            self.match_data = null;
        }
        pcre2c.pcre2_code_free_8(self.code);
        self.* = undefined;
    }

    /// Compile a pattern. Use default options (UTF, etc.) or customize via `options`.
    pub fn compile(pattern: []const u8, options: CompileOptions) CompileError!Self {
        var err_num: c_int = 0;
        var err_off: pcre2c.PCRE2_SIZE = 0;
        const code = pcre2c.pcre2_compile_8(
            pattern.ptr,
            pattern.len,
            options.toPcre2Flags(),
            &err_num,
            &err_off,
            null,
        );
        if (code == null) {
            return switch (err_num) {
                pcre2c.PCRE2_ERROR_PATTERN_TOO_LARGE => CompileError.PatternTooLarge,
                pcre2c.PCRE2_ERROR_PARENTHESES_NEST_TOO_DEEP => CompileError.NestLimit,
                pcre2c.PCRE2_ERROR_HEAP_FAILED => CompileError.HeapFailed,
                else => CompileError.InvalidPattern,
            };
        }
        const md = pcre2c.pcre2_match_data_create_from_pattern_8(code, null);
        return .{
            .code = code.?,
            .match_data = md,
        };
    }

    /// Compile a literal string (no regex metacharacters).
    pub fn compileLiteral(pattern: []const u8) CompileError!Self {
        return compile(pattern, .{ .literal = true });
    }
};

test "Pattern.compile" {
    var pat = try Pattern.compile("a", .{});
    defer pat.deinit();
    try std.testing.expect(pat.code != null);
}

test "Pattern.compileLiteral" {
    var pat = try Pattern.compileLiteral("hello");
    defer pat.deinit();
    try std.testing.expect(pat.code != null);
}

// ----------------------------------------------------------------------------
// Match (slices into subject; no allocator)
const MAX_GROUPS = 32;

pub const Match = struct {
    /// Subject string; all slices below are into this.
    subject: []const u8,
    /// [0] = full match start/end; [1..] = capture groups. Unset = start == end or UNSET.
    pairs: [MAX_GROUPS][2]usize,
    /// Number of pairs set (1 + group count).
    n: u32,

    /// Full match slice.
    pub fn full(self: *const Match) []const u8 {
        if (self.n == 0) return self.subject[0..0];
        const s = self.pairs[0][0];
        const e = self.pairs[0][1];
        if (s == std.math.maxInt(usize) or e == std.math.maxInt(usize)) return self.subject[0..0];
        return self.subject[s..e];
    }

    /// Capture group by index (0 = full match, 1 = first group, etc.). Returns empty slice if unset.
    pub fn group(self: *const Match, index: u32) []const u8 {
        if (index >= self.n) return self.subject[0..0];
        const s = self.pairs[index][0];
        const e = self.pairs[index][1];
        if (s == std.math.maxInt(usize) or e == std.math.maxInt(usize)) return self.subject[0..0];
        return self.subject[s..e];
    }

    /// Number of capture groups (excluding full match).
    pub fn groupCount(self: *const Match) u32 {
        if (self.n <= 1) return 0;
        return self.n - 1;
    }
};

fn matchInternal(
    subject: []const u8,
    pat: *const Pattern,
    start_offset: usize,
) ?Match {
    const md = pat.match_data orelse return null;
    const rc = pcre2c.pcre2_match_8(
        pat.code,
        subject.ptr,
        subject.len,
        start_offset,
        0,
        md,
        null,
    );
    if (rc == pcre2c.PCRE2_ERROR_NOMATCH or rc < 0) return null;
    const ovec = pcre2c.pcre2_get_ovector_pointer_8(md);
    const n = pcre2c.pcre2_get_ovector_count_8(md);
    const cap = @min(n, MAX_GROUPS);
    var m: Match = .{
        .subject = subject,
        .pairs = undefined,
        .n = @intCast(cap),
    };
    for (0..cap) |i| {
        const start = ovec[2 * i];
        const end = ovec[2 * i + 1];
        if (start == PCRE2_UNSET_val or end == PCRE2_UNSET_val) {
            m.pairs[i][0] = std.math.maxInt(usize);
            m.pairs[i][1] = std.math.maxInt(usize);
        } else {
            m.pairs[i][0] = start;
            m.pairs[i][1] = end;
        }
    }
    return m;
}

/// Single match in `subject` starting at `start_offset`. Returns null if no match.
pub fn match(subject: []const u8, pat: *const Pattern, start_offset: usize) ?Match {
    return matchInternal(subject, pat, start_offset);
}

test match {
    var pat = try Pattern.compile("(hello)|(world)", .{});
    defer pat.deinit();
    const m = match("hello world", &pat, 0);
    try std.testing.expect(m != null);
    try std.testing.expectEqualStrings(m.?.full(), "hello");
    try std.testing.expectEqualStrings(m.?.group(1), "hello");
}

/// First occurrence of pattern in subject (same as match at 0, then advance if you need “find”).
pub fn search(subject: []const u8, pat: *const Pattern) ?Match {
    return match(subject, pat, 0);
}

/// Returns true if pattern matches anywhere in subject.
pub fn isMatch(subject: []const u8, pat: *const Pattern) bool {
    return match(subject, pat, 0) != null;
}

test isMatch {
    var pat = try Pattern.compile("\\d+", .{});
    defer pat.deinit();
    try std.testing.expect(isMatch("a1b", &pat));
    try std.testing.expect(!isMatch("abc", &pat));
}

// ----------------------------------------------------------------------------
// Find all non-overlapping matches (requires allocator)
pub fn findAll(allocator: std.mem.Allocator, subject: []const u8, pat: *const Pattern) ![]Match {
    var list = std.ArrayList(Match).empty;
    errdefer list.deinit(allocator);
    var start: usize = 0;
    while (start <= subject.len) {
        const m = match(subject, pat, start) orelse break;
        try list.append(allocator, m);
        const full = m.full();
        if (full.len == 0) break;
        start = (m.pairs[0][0] + full.len);
    }
    return try list.toOwnedSlice(allocator);
}

test findAll {
    var pat = try Pattern.compile("\\d+", .{});
    defer pat.deinit();
    var matches = try findAll(std.testing.allocator, "a1b22c", &pat);
    defer std.testing.allocator.free(matches);
    try std.testing.expect(matches.len == 2);
    try std.testing.expectEqualStrings(matches[0].full(), "1");
    try std.testing.expectEqualStrings(matches[1].full(), "22");
}

// ----------------------------------------------------------------------------
// Replace (substitute): requires allocator for output
pub fn replace(
    allocator: std.mem.Allocator,
    subject: []const u8,
    pat: *const Pattern,
    replacement: []const u8,
    global: bool,
) ![]const u8 {
    var out_len: pcre2c.PCRE2_SIZE = 256;
    var buf = try allocator.alloc(u8, out_len);
    defer allocator.free(buf);
    var options: u32 = 0;
    if (global) options |= PCRE2_SUBSTITUTE_GLOBAL;
    const rc = pcre2c.pcre2_substitute_8(
        pat.code,
        subject.ptr,
        subject.len,
        0,
        options,
        null,
        null,
        replacement.ptr,
        replacement.len,
        buf.ptr,
        &out_len,
    );
    if (rc == PCRE2_ERROR_NOMEMORY and out_len > buf.len) {
        allocator.free(buf);
        buf = try allocator.alloc(u8, out_len);
        const rc2 = pcre2c.pcre2_substitute_8(
            pat.code,
            subject.ptr,
            subject.len,
            0,
            options,
            null,
            null,
            replacement.ptr,
            replacement.len,
            buf.ptr,
            &out_len,
        );
        if (rc2 < 0) return error.SubstituteFailed;
        return try allocator.dupe(u8, buf[0..out_len]);
    }
    if (rc < 0) return error.SubstituteFailed;
    return try allocator.dupe(u8, buf[0..out_len]);
}

test replace {
    var pat = try Pattern.compile("x", .{});
    defer pat.deinit();
    const out = try replace(std.testing.allocator, "axbxc", &pat, "Y", true);
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings(out, "aYbYc");
}
