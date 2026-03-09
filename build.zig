const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const bundle_re2 = b.option(bool, "bundle-re2", "Build and expose the bundled RE2 module") orelse false;

    const build_options = b.addOptions();
    build_options.addOption(bool, "bundle_re2", bundle_re2);

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

    var re2_dep: ?*std.Build.Dependency = null;
    var re2_mod: ?*std.Build.Module = null;
    var re2_build_step: ?*std.Build.Step = null;

    if (bundle_re2) {
        re2_dep = b.dependency("re2", .{
            .target = target,
            .optimize = optimize,
        });

        // Build RE2 from modules/re2 with CMake (RE2's CMakeLists requires Abseil).
        const re2_configure = b.addSystemCommand(&.{ "cmake" });
        re2_configure.setCwd(b.path("."));
        re2_configure.addArg("-S");
        re2_configure.addArg("modules/re2");
        re2_configure.addArg("-B");
        re2_configure.addArg("re2-build");
        re2_configure.addArg("-DCMAKE_BUILD_TYPE=Release");
        re2_configure.addArg("-DBUILD_SHARED_LIBS=OFF");
        re2_configure.addArg("-DRE2_BUILD_TESTING=OFF");
        re2_configure.addArg("-DRE2_TEST=OFF");
        re2_configure.addArg("-DRE2_INSTALL=OFF");

        const re2_build = b.addSystemCommand(&.{ "cmake", "--build", "re2-build" });
        re2_build.setCwd(b.path("."));
        re2_build.step.dependOn(&re2_configure.step);
        re2_build_step = &re2_build.step;

        const bundled_re2_mod = b.addModule("re2", .{
            .root_source_file = b.path("src/lib/re2.zig"),
            .target = target,
            .optimize = optimize,
        });
        bundled_re2_mod.addIncludePath(b.path("src/re2_ffi"));
        re2_mod = bundled_re2_mod;
    }

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

    const tests_root = b.createModule(.{
        .root_source_file = b.path("tests/suite.zig"),
        .target = target,
        .optimize = optimize,
    });
    tests_root.addImport("pcre2", pcre2_mod);
    tests_root.addOptions("build_options", build_options);
    if (re2_mod) |bundled_re2_mod| {
        tests_root.addImport("re2", bundled_re2_mod);
    }

    const tests = b.addTest(.{
        .root_module = tests_root,
    });
    if (re2_build_step) |step| {
        tests.addCSourceFile(.{
            .file = b.path("src/re2_ffi/re2_ffi.cpp"),
            .flags = &.{ "-std=c++17" },
        });
        tests.linkLibCpp();
        tests.step.dependOn(step);
        tests.addLibraryPath(b.path("re2-build/re2"));
        tests.addLibraryPath(b.path("re2-build/re2/Release"));
        tests.addIncludePath(re2_dep.?.path("."));
        tests.linkSystemLibrary("re2");
    }

    const tests_step = b.step("tests", "Run the test suite");
    const run_tests = b.addRunArtifact(tests);
    tests_step.dependOn(&run_tests.step);
}
