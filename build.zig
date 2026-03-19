const std = @import("std");

const pcre2_build = @import("pcre2");
const abseil_build = @import("abseil.build.zig");
const re2_build = @import("re2.build.zig");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const pcre2_options = b.addOptions();

    const pcre2_jit = b.option(bool, "pcre2-jit", "Toggle JIT support for PCRE2") orelse true;

    const pcre2_width = b.option(
        pcre2_build.CodeUnitWidth,
        "pcre2-width",
        "Set the code unit width for PCRE2",
    ) orelse .@"8";

    pcre2_options.addOption(pcre2_build.CodeUnitWidth, "code_unit_width", pcre2_width);
    pcre2_options.addOption(bool, "support_jit", pcre2_jit);

    const pcre2_dep = b.dependency("pcre2", .{
        .target = target,
        .optimize = optimize,
        .support_jit = pcre2_jit,
        .@"code-unit-width" = pcre2_width,
    });

    const pcre2_mod = b.addModule(
        "pcre2",
        .{
            .root_source_file = b.path("src/lib/pcre2.zig"),
            .target = target,
            .optimize = optimize,
        },
    );

    pcre2_mod.addOptions("pcre2_options", pcre2_options);

    const pcre2_artifact_name = switch (pcre2_width) {
        .@"8" => "pcre2-8",
        .@"16" => "pcre2-16",
        .@"32" => "pcre2-32",
    };

    pcre2_mod.linkLibrary(pcre2_dep.artifact(pcre2_artifact_name));

    const abseil_lib = abseil_build.build(b, target, optimize);
    const re2_lib = re2_build.build(b, target, optimize, abseil_lib);

    const re2_mod = b.addModule("re2", .{
        .root_source_file = b.path("src/lib/re2.zig"),
        .target = target,
        .optimize = optimize,
    });

    re2_mod.addIncludePath(b.path("src/re2_ffi"));
    re2_mod.linkLibrary(re2_lib);

    const docs_step = b.step("docs", "Generate the documentation");

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

    docs_step.dependOn(&docs.step);

    const tests_step = b.step("tests", "Run the test suite");

    const test_suite = b.createModule(.{
        .root_source_file = b.path("tests/suite.zig"),
        .target = target,
        .optimize = optimize,
    });

    test_suite.addImport("pcre2", pcre2_mod);
    test_suite.addImport("re2", re2_mod);

    const integration_tests = b.addTest(.{
        .root_module = test_suite,
    });

    integration_tests.root_module.addCSourceFile(.{
        .file = b.path("src/re2_ffi/re2_ffi.cpp"),
        .flags = &.{"-std=c++17"},
    });

    integration_tests.root_module.link_libcpp = true;
    integration_tests.root_module.addIncludePath(b.path("src/re2_ffi"));

    integration_tests.root_module.addIncludePath(b.dependency("re2", .{
        .target = target,
        .optimize = optimize,
    }).path("."));

    integration_tests.root_module.addIncludePath(b.dependency("abseil", .{
        .target = target,
        .optimize = optimize,
    }).path("."));

    integration_tests.root_module.linkLibrary(re2_lib);

    if (target.result.os.tag == .windows) {
        integration_tests.root_module.linkSystemLibrary("dbghelp", .{});
        integration_tests.root_module.linkSystemLibrary("bcrypt", .{});
    }

    const run_integration_tests = b.addRunArtifact(integration_tests);
    tests_step.dependOn(&run_integration_tests.step);
}
