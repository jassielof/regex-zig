const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const pcre2_dep = b.dependency("pcre2", .{
        .target = target,
        .optimize = optimize,
    });

    const pcre2_headers = b.addWriteFiles();
    _ = pcre2_headers.addCopyFile(pcre2_dep.path("src/pcre2.h.generic"), "pcre2.h");

    const pcre2_mod = b.addModule("pcre2", .{
        .root_source_file = b.path("src/lib/pcre2.zig"),
        .target = target,
        .optimize = optimize,
    });
    pcre2_mod.addIncludePath(pcre2_headers.getDirectory());
    pcre2_mod.linkLibrary(pcre2_dep.artifact("pcre2-8"));

    const re2_mod = b.addModule("re2", .{
        .root_source_file = b.path("src/lib/re2.zig"),
        .target = target,
        .optimize = optimize,
    });

    const docs_lib = b.addLibrary(.{
        .name = "regex",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/lib/root.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const docs = b.addInstallDirectory(.{
        .source_dir = docs_lib.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs",
    });

    const docs_step = b.step("docs", "Generate the documentation");
    docs_step.dependOn(&docs.step);

    const tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/suite.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{
                    .name = "pcre2",
                    .module = pcre2_mod,
                },
                .{
                    .name = "re2",
                    .module = re2_mod,
                },
            },
        }),
    });

    const tests_step = b.step("tests", "Run the test suite");
    const run_tests = b.addRunArtifact(tests);
    tests_step.dependOn(&run_tests.step);
}
