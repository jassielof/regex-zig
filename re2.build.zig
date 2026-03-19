const std = @import("std");

const sources = .{
    "re2/bitmap256.cc",
    "re2/bitstate.cc",
    "re2/compile.cc",
    "re2/dfa.cc",
    "re2/filtered_re2.cc",
    "re2/mimics_pcre.cc",
    "re2/nfa.cc",
    "re2/onepass.cc",
    "re2/parse.cc",
    "re2/perl_groups.cc",
    "re2/prefilter.cc",
    "re2/prefilter_tree.cc",
    "re2/prog.cc",
    "re2/re2.cc",
    "re2/regexp.cc",
    "re2/set.cc",
    "re2/simplify.cc",
    "re2/tostring.cc",
    "re2/unicode_casefold.cc",
    "re2/unicode_groups.cc",
    "util/rune.cc",
    "util/strutil.cc",
};

pub fn build(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    abseil_lib: *std.Build.Step.Compile,
    // abseil_include: *std.Build.LazyPath,
) *std.Build.Step.Compile {
    const dep = b.dependency("re2", .{
        .target = target,
        .optimize = optimize,
    });

    const abseil_dep = b.dependency("abseil", .{
        .target = target,
        .optimize = optimize,
    });

    const flags: []const []const u8 = if (target.result.os.tag != .windows) blk: {
        break :blk switch (target.result.cpu.arch) {
            .wasm32, .wasm64 => &.{},
            else => &.{"-pthread"},
        };
    } else &.{};

    const lib = b.addLibrary(.{
        .name = "re2",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libcpp = true,
        }),
    });

    lib.root_module.addIncludePath(dep.path("."));
    lib.root_module.addIncludePath(abseil_dep.path("."));

    lib.root_module.addCSourceFiles(.{
        .root = dep.path("."),
        .files = &sources,
        .flags = flags,
    });

    lib.root_module.linkLibrary(abseil_lib);

    return lib;
}
