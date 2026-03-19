//! PCRE2 bindings: convenient, Python `re` / C# `Regex`-style API over PCRE2.
//!
//! **Code unit width** is selected at build time via `-Dpcre2-width=8|16|32`
//! (default: `8`).  All string arguments use `[]const Char` — which is `u8`
//! for the default 8-bit build, `u16` for 16-bit, and `u32` for 32-bit.
//! Run integration tests with each width in CI (separate `zig build test` invocations).
//!
//! **JIT** is enabled at build time via `-Dpcre2-jit=true` (default: `true`).
//! When enabled, `Pattern.compile` calls `pcre2_jit_compile` after compile **unless**
//! `MatchLimits` are set — JIT matching does not honor
//! match/depth/heap limits, so JIT is skipped when any limit is configured.
//!
//! **Catastrophic backtracking mitigation:** PCRE2 provides *match limit* (how many
//! times the match engine may iterate), *depth limit* (parentheses/recursion depth),
//! and *heap limit* (bytes of heap used during match). Set these via
//! `CompileOptions.limits`. When exceeded, `match`,
//! `search`, `findAll`, and `replace` return `MatchError.MatchLimitExceeded`,
//! `MatchError.DepthLimitExceeded`, or `MatchError.HeapLimitExceeded` respectively
//! (see `pcre2_match(3)`).
//!
//! Zero-copy where possible; an allocator is only required for `replace` and `findAll`.
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

// ----------------------------------------------------------------------------
// Width helpers

/// Suffix string matching the configured code unit width: `"8"`, `"16"`, or `"32"`.
const width_suffix = @tagName(pcre2_options.code_unit_width);

/// Code unit width selected at build time (`-Dpcre2-width=…`).
pub const configured_code_unit_width = pcre2_options.code_unit_width;

fn pcre2Type(comptime base: []const u8) type {
    return @field(pcre2c, base ++ "_" ++ width_suffix);
}

/// The character element type for the configured code unit width.
pub const Char = switch (pcre2_options.code_unit_width) {
    .@"8" => u8,
    .@"16" => u16,
    .@"32" => u32,
};

pub const jit_enabled = pcre2_options.support_jit;

// ----------------------------------------------------------------------------
// Width-aware C type aliases

const Pcre2Code = pcre2Type("pcre2_code");
const Pcre2MatchData = pcre2Type("pcre2_match_data");
const Pcre2MatchContext = pcre2Type("pcre2_match_context");

// ----------------------------------------------------------------------------
// Width-aware C function references

const pcre2_compile_fn = @field(pcre2c, "pcre2_compile_" ++ width_suffix);
const pcre2_code_free_fn = @field(pcre2c, "pcre2_code_free_" ++ width_suffix);
const pcre2_match_data_create_fn = @field(pcre2c, "pcre2_match_data_create_from_pattern_" ++ width_suffix);
const pcre2_match_data_free_fn = @field(pcre2c, "pcre2_match_data_free_" ++ width_suffix);
const pcre2_match_fn = @field(pcre2c, "pcre2_match_" ++ width_suffix);
const pcre2_jit_compile_fn = @field(pcre2c, "pcre2_jit_compile_" ++ width_suffix);
const pcre2_jit_match_fn = @field(pcre2c, "pcre2_jit_match_" ++ width_suffix);
const pcre2_get_ovector_pointer_fn = @field(pcre2c, "pcre2_get_ovector_pointer_" ++ width_suffix);
const pcre2_get_ovector_count_fn = @field(pcre2c, "pcre2_get_ovector_count_" ++ width_suffix);
const pcre2_substitute_fn = @field(pcre2c, "pcre2_substitute_" ++ width_suffix);
const pcre2_get_error_message_fn = @field(pcre2c, "pcre2_get_error_message_" ++ width_suffix);
const pcre2_match_context_create_fn = @field(pcre2c, "pcre2_match_context_create_" ++ width_suffix);
const pcre2_match_context_free_fn = @field(pcre2c, "pcre2_match_context_free_" ++ width_suffix);
const pcre2_set_match_limit_fn = @field(pcre2c, "pcre2_set_match_limit_" ++ width_suffix);
const pcre2_set_depth_limit_fn = @field(pcre2c, "pcre2_set_depth_limit_" ++ width_suffix);
const pcre2_set_heap_limit_fn = @field(pcre2c, "pcre2_set_heap_limit_" ++ width_suffix);

// ----------------------------------------------------------------------------
// C constants

const PCRE2_UNSET_val = std.math.maxInt(usize);
const PCRE2_ERROR_NOMATCH = pcre2c.PCRE2_ERROR_NOMATCH;
const PCRE2_ERROR_NOMEMORY = pcre2c.PCRE2_ERROR_NOMEMORY;
const PCRE2_ERROR_MATCHLIMIT = pcre2c.PCRE2_ERROR_MATCHLIMIT;
const PCRE2_ERROR_DEPTHLIMIT = pcre2c.PCRE2_ERROR_DEPTHLIMIT;
const PCRE2_ERROR_HEAPLIMIT = pcre2c.PCRE2_ERROR_HEAPLIMIT;
const PCRE2_SUBSTITUTE_GLOBAL = pcre2c.PCRE2_SUBSTITUTE_GLOBAL;
const PCRE2_CASELESS = pcre2c.PCRE2_CASELESS;
const PCRE2_MULTILINE = pcre2c.PCRE2_MULTILINE;
const PCRE2_DOTALL = pcre2c.PCRE2_DOTALL;
const PCRE2_UTF = pcre2c.PCRE2_UTF;
const PCRE2_LITERAL = pcre2c.PCRE2_LITERAL;
const PCRE2_JIT_COMPLETE = pcre2c.PCRE2_JIT_COMPLETE;

// ----------------------------------------------------------------------------
/// Limits applied during matching to mitigate catastrophic backtracking / runaway recursion.
///
/// Maps to `pcre2_set_match_limit`, `pcre2_set_depth_limit`, and `pcre2_set_heap_limit`.
/// Use `null` for a field to leave that limit at the library default (from `config.h`).
///
/// When any limit is set, JIT compilation is **disabled** for that pattern so limits are enforced.
pub const MatchLimits = struct {
    match_limit: ?u32 = null,
    depth_limit: ?u32 = null,
    heap_limit: ?u32 = null,

    fn active(self: MatchLimits) bool {
        return self.match_limit != null or self.depth_limit != null or self.heap_limit != null;
    }
};

pub const CompileOptions = struct {
    caseless: bool = false,
    multiline: bool = false,
    dotall: bool = false,
    utf: bool = true,
    literal: bool = false,
    /// Optional match / depth / heap limits (see [`MatchLimits`]).
    limits: ?MatchLimits = null,

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

pub const CompileError = error{
    InvalidPattern,
    PatternTooLarge,
    NestLimit,
    HeapFailed,
    Other,
};

/// Returned when matching hits a configured limit or an unexpected engine error.
pub const MatchError = error{
    MatchLimitExceeded,
    DepthLimitExceeded,
    HeapLimitExceeded,
    MatchEngineFailed,
    /// `pcre2_substitute` returned an error other than a limit or resize.
    SubstituteFailed,
};

pub fn getErrorMessage(code: c_int, buffer: []Char) []const Char {
    if (buffer.len == 0) return buffer[0..0];
    const n = pcre2_get_error_message_fn(code, buffer.ptr, buffer.len);
    if (n <= 0) return buffer[0..0];
    return buffer[0..@min(@as(usize, @intCast(n)), buffer.len)];
}

// ----------------------------------------------------------------------------
pub const Pattern = struct {
    code: *Pcre2Code,
    match_data: ?*Pcre2MatchData,
    /// Non-null when [`CompileOptions.limits`] was set with at least one field.
    match_context: ?*Pcre2MatchContext,
    jit: bool,

    const Self = @This();

    pub fn deinit(self: *Self) void {
        if (self.match_data) |md| {
            pcre2_match_data_free_fn(md);
            self.match_data = null;
        }
        if (self.match_context) |mc| {
            pcre2_match_context_free_fn(mc);
            self.match_context = null;
        }
        pcre2_code_free_fn(self.code);
        self.* = undefined;
    }

    pub fn compile(pattern: []const Char, options: CompileOptions) CompileError!Self {
        var err_num: c_int = 0;
        var err_off: pcre2c.PCRE2_SIZE = 0;
        const code = pcre2_compile_fn(
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

        const md = pcre2_match_data_create_fn(code, null);

        var mctx: ?*Pcre2MatchContext = null;
        const limits_on = if (options.limits) |l| l.active() else false;
        if (limits_on) {
            const ctx = pcre2_match_context_create_fn(null) orelse return CompileError.HeapFailed;
            mctx = ctx;
            const lim = options.limits.?;
            if (lim.match_limit) |n| {
                _ = pcre2_set_match_limit_fn(ctx, n);
            }
            if (lim.depth_limit) |n| {
                _ = pcre2_set_depth_limit_fn(ctx, n);
            }
            if (lim.heap_limit) |n| {
                _ = pcre2_set_heap_limit_fn(ctx, n);
            }
        }

        // JIT does not enforce match/depth/heap limits; skip JIT when limits are active.
        const try_jit = jit_enabled and !limits_on;
        const jit: bool = if (try_jit)
            pcre2_jit_compile_fn(code.?, PCRE2_JIT_COMPLETE) == 0
        else
            false;

        return .{
            .code = code.?,
            .match_data = md,
            .match_context = mctx,
            .jit = jit,
        };
    }

    pub fn compileLiteral(pattern: []const Char) CompileError!Self {
        return compile(pattern, .{ .literal = true });
    }
};

test "Pattern.compile" {
    var pat = try Pattern.compile("a", .{});
    defer pat.deinit();
    try std.testing.expect(pat.code != undefined);
}

test "Pattern.compileLiteral" {
    var pat = try Pattern.compileLiteral("hello");
    defer pat.deinit();
    try std.testing.expect(pat.code != undefined);
}

test "Pattern.jit reflects jit_enabled when no limits" {
    var pat = try Pattern.compile("\\d+", .{});
    defer pat.deinit();
    try std.testing.expect(pat.jit == jit_enabled);
}

test "Pattern.jit disabled when limits set" {
    var pat = try Pattern.compile("\\d+", .{ .limits = .{ .match_limit = 1000 } });
    defer pat.deinit();
    try std.testing.expect(!pat.jit);
}

// ----------------------------------------------------------------------------
const MAX_GROUPS = 32;

pub const Match = struct {
    subject: []const Char,
    pairs: [MAX_GROUPS][2]usize,
    n: u32,

    pub fn full(self: *const Match) []const Char {
        if (self.n == 0) return self.subject[0..0];
        const s = self.pairs[0][0];
        const e = self.pairs[0][1];
        if (s == std.math.maxInt(usize) or e == std.math.maxInt(usize)) return self.subject[0..0];
        return self.subject[s..e];
    }

    pub fn group(self: *const Match, index: u32) []const Char {
        if (index >= self.n) return self.subject[0..0];
        const s = self.pairs[index][0];
        const e = self.pairs[index][1];
        if (s == std.math.maxInt(usize) or e == std.math.maxInt(usize)) return self.subject[0..0];
        return self.subject[s..e];
    }

    pub fn groupCount(self: *const Match) u32 {
        if (self.n <= 1) return 0;
        return self.n - 1;
    }
};

fn matchInternal(
    subject: []const Char,
    pat: *const Pattern,
    start_offset: usize,
) MatchError!?Match {
    const md = pat.match_data orelse return null;
    const mctx = pat.match_context;
    const rc: c_int = if (pat.jit)
        pcre2_jit_match_fn(pat.code, subject.ptr, subject.len, start_offset, 0, md, mctx)
    else
        pcre2_match_fn(pat.code, subject.ptr, subject.len, start_offset, 0, md, mctx);

    if (rc == PCRE2_ERROR_NOMATCH) return null;
    if (rc == PCRE2_ERROR_MATCHLIMIT) return error.MatchLimitExceeded;
    if (rc == PCRE2_ERROR_DEPTHLIMIT) return error.DepthLimitExceeded;
    if (rc == PCRE2_ERROR_HEAPLIMIT) return error.HeapLimitExceeded;
    if (rc < 0) return error.MatchEngineFailed;

    const ovec = pcre2_get_ovector_pointer_fn(md);
    const n = pcre2_get_ovector_count_fn(md);
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

/// No match → `null`. Limit or engine failure → `MatchError`.
pub fn match(subject: []const Char, pat: *const Pattern, start_offset: usize) MatchError!?Match {
    return matchInternal(subject, pat, start_offset);
}

test match {
    var pat = try Pattern.compile("(hello)|(world)", .{});
    defer pat.deinit();
    const m = try match("hello world", &pat, 0);
    try std.testing.expect(m != null);
    try std.testing.expectEqualStrings(m.?.full(), "hello");
    try std.testing.expectEqualStrings(m.?.group(1), "hello");
}

test "match: JIT and interpreter agree" {
    var pat = try Pattern.compile("(\\d+)-(\\d+)", .{});
    defer pat.deinit();
    const m = try match("abc 10-20 xyz", &pat, 0);
    try std.testing.expect(m != null);
    try std.testing.expectEqualStrings(m.?.full(), "10-20");
    try std.testing.expectEqualStrings(m.?.group(1), "10");
    try std.testing.expectEqualStrings(m.?.group(2), "20");
}

test "match limit stops excessive backtracking" {
    const pat_src: []const Char = switch (Char) {
        u8 => "(a+)*zz",
        u16 => &[_]Char{ '(', 'a', '+', ')', '*', 'z', 'z' },
        u32 => &[_]Char{ '(', 'a', '+', ')', '*', 'z', 'z' },
        else => @compileError("Char"),
    };
    const sub_ascii = "aaaaaaaaaaaaaz";
    const subject = try std.testing.allocator.alloc(Char, sub_ascii.len);
    defer std.testing.allocator.free(subject);
    for (sub_ascii, 0..) |c, i| subject[i] = @as(Char, c);

    var pat = try Pattern.compile(pat_src, .{ .limits = .{ .match_limit = 3000 } });
    defer pat.deinit();
    const r = match(subject, &pat, 0);
    try std.testing.expectError(error.MatchLimitExceeded, r);
}

pub fn search(subject: []const Char, pat: *const Pattern) MatchError!?Match {
    return match(subject, pat, 0);
}

pub fn isMatch(subject: []const Char, pat: *const Pattern) MatchError!bool {
    return (try match(subject, pat, 0)) != null;
}

test isMatch {
    var pat = try Pattern.compile("\\d+", .{});
    defer pat.deinit();
    try std.testing.expect(try isMatch("a1b", &pat));
    try std.testing.expect(!try isMatch("abc", &pat));
}

pub fn findAll(allocator: std.mem.Allocator, subject: []const Char, pat: *const Pattern) (MatchError || error{OutOfMemory})![]Match {
    var list = std.ArrayList(Match).empty;
    errdefer list.deinit(allocator);
    var start: usize = 0;
    while (start <= subject.len) {
        const m = try match(subject, pat, start) orelse break;
        try list.append(allocator, m);
        const full_slice = m.full();
        if (full_slice.len == 0) break;
        start = m.pairs[0][0] + full_slice.len;
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

/// Errors: [`MatchError`] from limit checks / substitute failure, or `error.OutOfMemory`.
pub fn replace(
    allocator: std.mem.Allocator,
    subject: []const Char,
    pat: *const Pattern,
    replacement: []const Char,
    global: bool,
) (MatchError || error{OutOfMemory})![]Char {
    var options: u32 = 0;
    if (global) options |= PCRE2_SUBSTITUTE_GLOBAL;

    var out_len: pcre2c.PCRE2_SIZE = 256;
    var buf = try allocator.alloc(Char, out_len);
    errdefer allocator.free(buf);

    const mctx = pat.match_context;
    const rc = pcre2_substitute_fn(
        pat.code,
        subject.ptr,
        subject.len,
        0,
        options,
        null,
        mctx,
        replacement.ptr,
        replacement.len,
        buf.ptr,
        &out_len,
    );

    if (rc == PCRE2_ERROR_NOMEMORY) {
        buf = try allocator.realloc(buf, out_len);
        const rc2 = pcre2_substitute_fn(
            pat.code,
            subject.ptr,
            subject.len,
            0,
            options,
            null,
            mctx,
            replacement.ptr,
            replacement.len,
            buf.ptr,
            &out_len,
        );
        if (rc2 == PCRE2_ERROR_MATCHLIMIT) return error.MatchLimitExceeded;
        if (rc2 == PCRE2_ERROR_DEPTHLIMIT) return error.DepthLimitExceeded;
        if (rc2 == PCRE2_ERROR_HEAPLIMIT) return error.HeapLimitExceeded;
        if (rc2 < 0) return error.SubstituteFailed;
        return allocator.realloc(buf, out_len);
    }

    if (rc == PCRE2_ERROR_MATCHLIMIT) return error.MatchLimitExceeded;
    if (rc == PCRE2_ERROR_DEPTHLIMIT) return error.DepthLimitExceeded;
    if (rc == PCRE2_ERROR_HEAPLIMIT) return error.HeapLimitExceeded;
    if (rc < 0) return error.SubstituteFailed;
    return allocator.realloc(buf, out_len);
}

test replace {
    var pat = try Pattern.compile("x", .{});
    defer pat.deinit();
    const out = try replace(std.testing.allocator, "axbxc", &pat, "Y", true);
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings(out, "aYbYc");
}

test "replace: single replacement" {
    var pat = try Pattern.compile("x", .{});
    defer pat.deinit();
    const out = try replace(std.testing.allocator, "axbxc", &pat, "Y", false);
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualStrings(out, "aYbxc");
}

test "Char type matches configured code unit width" {
    switch (pcre2_options.code_unit_width) {
        .@"8" => try std.testing.expect(Char == u8),
        .@"16" => try std.testing.expect(Char == u16),
        .@"32" => try std.testing.expect(Char == u32),
    }
}
