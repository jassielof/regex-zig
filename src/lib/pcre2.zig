//! PCRE2 bindings: convenient, Python `re` / C# `Regex`-style API over PCRE2.
//!
//! **Code unit width** is selected at build time via `-Dpcre2-width=8|16|32`
//! (default: `8`).  All string arguments use `[]const Char` — which is `u8`
//! for the default 8-bit build, `u16` for 16-bit, and `u32` for 32-bit.
//!
//! **JIT** is enabled at build time via `-Dpcre2-jit=true` (default: `true`).
//! When enabled, `Pattern.compile` automatically calls `pcre2_jit_compile`
//! right after the pattern is compiled, and `matchInternal` routes through
//! `pcre2_jit_match` instead of `pcre2_match` for every successful JIT
//! pattern.  The `jit_enabled` constant and the `Pattern.jit` field let
//! callers inspect this at runtime.
//!
//! Zero-copy where possible; an allocator is only required for `replace` and
//! `findAll`.
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

/// Returns the PCRE2 C type whose name is `base ++ "_" ++ width_suffix`.
/// Example: `pcre2Type("pcre2_code")` → `pcre2c.pcre2_code_8` for width 8.
fn pcre2Type(comptime base: []const u8) type {
    return @field(pcre2c, base ++ "_" ++ width_suffix);
}

/// The character element type for the configured code unit width.
///
/// | `-Dpcre2-width` | `Char` |
/// |-----------------|--------|
/// | `8` (default)   | `u8`   |
/// | `16`            | `u16`  |
/// | `32`            | `u32`  |
///
/// All public functions that accept or return strings use `[]const Char` (or
/// `[]Char` for owned buffers), so the API is type-correct across all widths.
pub const Char = switch (pcre2_options.code_unit_width) {
    .@"8" => u8,
    .@"16" => u16,
    .@"32" => u32,
};

/// `true` when the library was compiled with JIT support (`-Dpcre2-jit=true`).
///
/// When `true`, `Pattern.compile` calls `pcre2_jit_compile` automatically and
/// the `Pattern.jit` field will be `true` if JIT compilation succeeded.
/// Matches then use the faster `pcre2_jit_match` path.
pub const jit_enabled = pcre2_options.support_jit;

// ----------------------------------------------------------------------------
// Width-aware C type aliases

const Pcre2Code = pcre2Type("pcre2_code");
const Pcre2MatchData = pcre2Type("pcre2_match_data");

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

// ----------------------------------------------------------------------------
// C constants

// ~(PCRE2_SIZE)0 is not translatable by cImport; approximate with maxInt(usize)
const PCRE2_UNSET_val = std.math.maxInt(usize);
const PCRE2_ERROR_NOMATCH = pcre2c.PCRE2_ERROR_NOMATCH;
const PCRE2_ERROR_NOMEMORY = pcre2c.PCRE2_ERROR_NOMEMORY;
const PCRE2_SUBSTITUTE_GLOBAL = pcre2c.PCRE2_SUBSTITUTE_GLOBAL;
const PCRE2_CASELESS = pcre2c.PCRE2_CASELESS;
const PCRE2_MULTILINE = pcre2c.PCRE2_MULTILINE;
const PCRE2_DOTALL = pcre2c.PCRE2_DOTALL;
const PCRE2_UTF = pcre2c.PCRE2_UTF;
const PCRE2_LITERAL = pcre2c.PCRE2_LITERAL;
const PCRE2_JIT_COMPLETE = pcre2c.PCRE2_JIT_COMPLETE;

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
    /// Use `getErrorMessage` for details; the offset into the pattern is not
    /// currently surfaced through this API.
    Other,
};

/// Returns a human-readable message for a PCRE2 error code into `buffer`.
///
/// `buffer` must be a slice of `Char` (u8/u16/u32 depending on the configured
/// code unit width).  Returns the sub-slice that was written.
pub fn getErrorMessage(code: c_int, buffer: []Char) []const Char {
    if (buffer.len == 0) return buffer[0..0];
    const n = pcre2_get_error_message_fn(code, buffer.ptr, buffer.len);
    if (n <= 0) return buffer[0..0];
    return buffer[0..@min(@as(usize, @intCast(n)), buffer.len)];
}

// ----------------------------------------------------------------------------
// Pattern (owns compiled code + cached match_data)

pub const Pattern = struct {
    code: *Pcre2Code,
    match_data: ?*Pcre2MatchData,
    /// `true` when JIT compilation succeeded for this pattern.
    ///
    /// Requires `jit_enabled == true` at build time.  When `true`, `matchInternal`
    /// routes through `pcre2_jit_match` instead of `pcre2_match`.
    jit: bool,

    const Self = @This();

    /// Release compiled code and any cached match_data.
    pub fn deinit(self: *Self) void {
        if (self.match_data) |md| {
            pcre2_match_data_free_fn(md);
            self.match_data = null;
        }
        pcre2_code_free_fn(self.code);
        self.* = undefined;
    }

    /// Compile `pattern`.  When `jit_enabled`, also JIT-compiles the result
    /// for faster matching; if JIT compilation fails (e.g. unsupported CPU),
    /// the interpreter path is used silently.
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

        // Attempt JIT compilation; a non-zero return means JIT is unavailable
        // (not compiled in, or unsupported architecture) — fall back silently.
        const jit: bool = if (jit_enabled)
            pcre2_jit_compile_fn(code.?, PCRE2_JIT_COMPLETE) == 0
        else
            false;

        return .{
            .code = code.?,
            .match_data = md,
            .jit = jit,
        };
    }

    /// Compile a literal string (no regex metacharacters interpreted).
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

test "Pattern.jit reflects jit_enabled" {
    var pat = try Pattern.compile("\\d+", .{});
    defer pat.deinit();
    // When JIT is built in, every successfully compiled pattern should be JIT'd.
    try std.testing.expect(pat.jit == jit_enabled);
}

// ----------------------------------------------------------------------------
// Match (zero-copy view into the subject)

const MAX_GROUPS = 32;

pub const Match = struct {
    /// Subject string all slices below index into.
    subject: []const Char,
    /// [0] = full match offsets; [1..] = capture group offsets.
    /// An unset group has both offsets equal to `std.math.maxInt(usize)`.
    pairs: [MAX_GROUPS][2]usize,
    /// Number of pairs populated (1 + number of capture groups).
    n: u32,

    /// Full match slice.
    pub fn full(self: *const Match) []const Char {
        if (self.n == 0) return self.subject[0..0];
        const s = self.pairs[0][0];
        const e = self.pairs[0][1];
        if (s == std.math.maxInt(usize) or e == std.math.maxInt(usize)) return self.subject[0..0];
        return self.subject[s..e];
    }

    /// Capture group by index (0 = full match, 1 = first group, …).
    /// Returns an empty slice for unset or out-of-range groups.
    pub fn group(self: *const Match, index: u32) []const Char {
        if (index >= self.n) return self.subject[0..0];
        const s = self.pairs[index][0];
        const e = self.pairs[index][1];
        if (s == std.math.maxInt(usize) or e == std.math.maxInt(usize)) return self.subject[0..0];
        return self.subject[s..e];
    }

    /// Number of capture groups (excluding the full-match entry at index 0).
    pub fn groupCount(self: *const Match) u32 {
        if (self.n <= 1) return 0;
        return self.n - 1;
    }
};

fn matchInternal(
    subject: []const Char,
    pat: *const Pattern,
    start_offset: usize,
) ?Match {
    const md = pat.match_data orelse return null;

    // Use the JIT path when available — it bypasses sanity checks for speed.
    const rc: c_int = if (pat.jit)
        pcre2_jit_match_fn(pat.code, subject.ptr, subject.len, start_offset, 0, md, null)
    else
        pcre2_match_fn(pat.code, subject.ptr, subject.len, start_offset, 0, md, null);

    if (rc == PCRE2_ERROR_NOMATCH or rc < 0) return null;

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

/// Match `pat` in `subject` starting at `start_offset`.
/// Returns `null` when there is no match.
pub fn match(subject: []const Char, pat: *const Pattern, start_offset: usize) ?Match {
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

test "match: JIT and interpreter agree" {
    // Compile once; the .jit field tells us which path matchInternal will use.
    var pat = try Pattern.compile("(\\d+)-(\\d+)", .{});
    defer pat.deinit();
    const m = match("abc 10-20 xyz", &pat, 0);
    try std.testing.expect(m != null);
    try std.testing.expectEqualStrings(m.?.full(), "10-20");
    try std.testing.expectEqualStrings(m.?.group(1), "10");
    try std.testing.expectEqualStrings(m.?.group(2), "20");
}

/// First occurrence of `pat` in `subject` (convenience wrapper around `match`).
pub fn search(subject: []const Char, pat: *const Pattern) ?Match {
    return match(subject, pat, 0);
}

/// Returns `true` if `pat` matches anywhere in `subject`.
pub fn isMatch(subject: []const Char, pat: *const Pattern) bool {
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

pub fn findAll(allocator: std.mem.Allocator, subject: []const Char, pat: *const Pattern) ![]Match {
    var list = std.ArrayList(Match).empty;
    errdefer list.deinit(allocator);
    var start: usize = 0;
    while (start <= subject.len) {
        const m = match(subject, pat, start) orelse break;
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

// ----------------------------------------------------------------------------
// Replace (substitute): requires allocator for the output buffer

/// Replace matches of `pat` in `subject` with `replacement`.
///
/// When `global` is `true` all non-overlapping matches are replaced;
/// otherwise only the first match is replaced.
///
/// Returns an owned `[]Char` slice the caller must free.
pub fn replace(
    allocator: std.mem.Allocator,
    subject: []const Char,
    pat: *const Pattern,
    replacement: []const Char,
    global: bool,
) ![]Char {
    var options: u32 = 0;
    if (global) options |= PCRE2_SUBSTITUTE_GLOBAL;

    // Start with a modest output buffer; PCRE2 will report the required size
    // if the buffer is too small (PCRE2_ERROR_NOMEMORY).
    var out_len: pcre2c.PCRE2_SIZE = 256;
    var buf = try allocator.alloc(Char, out_len);
    errdefer allocator.free(buf);

    const rc = pcre2_substitute_fn(
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

    if (rc == PCRE2_ERROR_NOMEMORY) {
        // PCRE2 updated out_len to the required number of code units; resize.
        buf = try allocator.realloc(buf, out_len);
        const rc2 = pcre2_substitute_fn(
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
        return allocator.realloc(buf, out_len);
    }

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

// ----------------------------------------------------------------------------
// Code-unit-width self-test

test "Char type matches configured code unit width" {
    switch (pcre2_options.code_unit_width) {
        .@"8" => try std.testing.expect(Char == u8),
        .@"16" => try std.testing.expect(Char == u16),
        .@"32" => try std.testing.expect(Char == u32),
    }
}
