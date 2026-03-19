const std = @import("std");

const abseil_base_sources = .{
    "log_severity.cc",
    "internal/raw_logging.cc",
    "internal/spinlock_wait.cc",
    "internal/low_level_alloc.cc",
    "internal/cycleclock.cc",
    "internal/spinlock.cc",
    "internal/sysinfo.cc",
    "internal/thread_identity.cc",
    "internal/unscaledcycleclock.cc",
    "internal/throw_delegate.cc",
    "internal/scoped_set_env.cc",
    "internal/strerror.cc",
    "internal/poison.cc",
    "internal/tracing.cc",
};

const abseil_container_sources = .{
    "internal/hashtablez_sampler.cc",
    "internal/hashtablez_sampler_force_weak_definition.cc",
    "internal/raw_hash_set.cc",
};

const abseil_hash_sources = .{
    "internal/hash.cc",
    "internal/city.cc",
};

const abseil_numeric_sources = .{
    "int128.cc",
};

const abseil_strings_sources = .{
    "ascii.cc",
    "charconv.cc",
    "escaping.cc",
    "internal/charconv_bigint.cc",
    "internal/charconv_parse.cc",
    "internal/damerau_levenshtein_distance.cc",
    "internal/memutil.cc",
    "internal/stringify_sink.cc",
    "match.cc",
    "numbers.cc",
    "str_cat.cc",
    "str_replace.cc",
    "str_split.cc",
    "substitute.cc",
    "internal/escaping.cc",
    "internal/ostringstream.cc",
    "internal/utf8.cc",
    "internal/str_format/arg.cc",
    "internal/str_format/bind.cc",
    "internal/str_format/extension.cc",
    "internal/str_format/float_conversion.cc",
    "internal/str_format/output.cc",
    "internal/str_format/parser.cc",
    "internal/pow10_helper.cc",
    "internal/cord_internal.cc",
    "internal/cord_rep_btree.cc",
    "internal/cord_rep_btree_navigator.cc",
    "internal/cord_rep_btree_reader.cc",
    "internal/cord_rep_crc.cc",
    "internal/cord_rep_consume.cc",
    "internal/cordz_functions.cc",
    "internal/cordz_handle.cc",
    "internal/cordz_info.cc",
    "internal/cordz_sample_token.cc",
    "cord.cc",
    "cord_analysis.cc",
};

const abseil_synchronization_sources = .{
    "internal/graphcycles.cc",
    "internal/kernel_timeout.cc",
    "barrier.cc",
    "blocking_counter.cc",
    "internal/create_thread_identity.cc",
    "internal/futex_waiter.cc",
    "internal/per_thread_sem.cc",
    "internal/pthread_waiter.cc",
    "internal/sem_waiter.cc",
    "internal/stdcpp_waiter.cc",
    "internal/waiter_base.cc",
    "internal/win32_waiter.cc",
    "notification.cc",
    "mutex.cc",
};

const abseil_status_sources = .{
    "internal/status_internal.cc",
    "status.cc",
    "status_payload_printer.cc",
    "statusor.cc",
};

const abseil_crc_sources = .{
    "crc32c.cc",
    "internal/cpu_detect.cc",
    "internal/crc.cc",
    "internal/crc_cord_state.cc",
    "internal/crc_memcpy_fallback.cc",
    "internal/crc_memcpy_x86_arm_combined.cc",
    "internal/crc_non_temporal_memcpy.cc",
    "internal/crc_x86_arm_combined.cc",
};

const abseil_debugging_sources = .{
    "stacktrace.cc",
    "symbolize.cc",
    "internal/examine_stack.cc",
    "failure_signal_handler.cc",
    "internal/address_is_readable.cc",
    "internal/elf_mem_image.cc",
    "internal/vdso_support.cc",
    "internal/demangle.cc",
    "internal/decode_rust_punycode.cc",
    "internal/demangle_rust.cc",
    "internal/utf8_for_code_point.cc",
    "leak_check.cc",
    "internal/stack_consumption.cc",
    "internal/borrowed_fixup_buffer.cc",
};

const abseil_time_sources = .{
    "civil_time.cc",
    "clock.cc",
    "duration.cc",
    "format.cc",
    "time.cc",
    "internal/cctz/src/civil_time_detail.cc",
    "internal/cctz/src/time_zone_fixed.cc",
    "internal/cctz/src/time_zone_format.cc",
    "internal/cctz/src/time_zone_if.cc",
    "internal/cctz/src/time_zone_impl.cc",
    "internal/cctz/src/time_zone_info.cc",
    "internal/cctz/src/time_zone_libc.cc",
    "internal/cctz/src/time_zone_lookup.cc",
    "internal/cctz/src/time_zone_posix.cc",
    "internal/cctz/src/zone_info_source.cc",
    "internal/cctz/src/time_zone_name_win.cc",
};

const abseil_log_sources = .{
    "internal/check_op.cc",
    "internal/conditions.cc",
    "internal/log_format.cc",
    "internal/globals.cc",
    "internal/proto.cc",
    "internal/log_message.cc",
    "internal/log_sink_set.cc",
    "internal/nullguard.cc",
    "die_if_null.cc",
    "flags.cc",
    "globals.cc",
    "initialize.cc",
    "log_sink.cc",
    "internal/structured_proto.cc",
    "internal/vlog_config.cc",
    "internal/fnmatch.cc",
};

const abseil_flags_sources = .{
    "internal/program_name.cc",
    "usage_config.cc",
    "marshalling.cc",
    "internal/commandlineflag.cc",
    "commandlineflag.cc",
    "internal/private_handle_accessor.cc",
    "reflection.cc",
    "internal/flag.cc",
    "internal/usage.cc",
    "usage.cc",
    "parse.cc",
};

const abseil_profiling_sources = .{
    "internal/exponential_biased.cc",
    "internal/periodic_sampler.cc",
};

const abseil_random_sources = .{
    "discrete_distribution.cc",
    "gaussian_distribution.cc",
    "seed_gen_exception.cc",
    "seed_sequences.cc",
    "internal/seed_material.cc",
    "internal/entropy_pool.cc",
    "internal/randen_round_keys.cc",
    "internal/randen.cc",
    "internal/randen_slow.cc",
    "internal/randen_detect.cc",
    "internal/randen_hwaes.cc",
    "internal/chi_square.cc",
    "internal/gaussian_distribution_gentables.cc",
    "internal/distribution_test_util.cc",
};

const re2_sources = .{
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

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // --- PCRE2 ---

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

    // --- Abseil ---

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

    const abseil_lib = b.addLibrary(.{
        .name = "abseil",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libcpp = true,
        }),
    });
    if (target.result.os.tag == .windows) {
        abseil_lib.linkSystemLibrary("dbghelp");
        abseil_lib.linkSystemLibrary("bcrypt");
    }
    abseil_lib.addIncludePath(abseil_dep.path("."));
    abseil_lib.addCSourceFiles(.{ .root = abseil_dep.path("absl/base"), .files = &abseil_base_sources, .flags = flags });
    abseil_lib.addCSourceFiles(.{ .root = abseil_dep.path("absl/container"), .files = &abseil_container_sources, .flags = flags });
    abseil_lib.addCSourceFiles(.{ .root = abseil_dep.path("absl/hash"), .files = &abseil_hash_sources, .flags = flags });
    abseil_lib.addCSourceFiles(.{ .root = abseil_dep.path("absl/numeric"), .files = &abseil_numeric_sources, .flags = flags });
    abseil_lib.addCSourceFiles(.{ .root = abseil_dep.path("absl/strings"), .files = &abseil_strings_sources, .flags = flags });
    abseil_lib.addCSourceFiles(.{ .root = abseil_dep.path("absl/synchronization"), .files = &abseil_synchronization_sources, .flags = flags });
    abseil_lib.addCSourceFiles(.{ .root = abseil_dep.path("absl/status"), .files = &abseil_status_sources, .flags = flags });
    abseil_lib.addCSourceFiles(.{ .root = abseil_dep.path("absl/crc"), .files = &abseil_crc_sources, .flags = flags });
    abseil_lib.addCSourceFiles(.{ .root = abseil_dep.path("absl/debugging"), .files = &abseil_debugging_sources, .flags = flags });
    abseil_lib.addCSourceFiles(.{ .root = abseil_dep.path("absl/time"), .files = &abseil_time_sources, .flags = flags });
    abseil_lib.addCSourceFiles(.{ .root = abseil_dep.path("absl/log"), .files = &abseil_log_sources, .flags = flags });
    abseil_lib.addCSourceFiles(.{ .root = abseil_dep.path("absl/flags"), .files = &abseil_flags_sources, .flags = flags });
    abseil_lib.addCSourceFiles(.{ .root = abseil_dep.path("absl/profiling"), .files = &abseil_profiling_sources, .flags = flags });
    abseil_lib.addCSourceFiles(.{ .root = abseil_dep.path("absl/random"), .files = &abseil_random_sources, .flags = flags });

    // --- RE2 ---

    const re2_dep = b.dependency("re2", .{
        .target = target,
        .optimize = optimize,
    });

    const re2_lib = b.addLibrary(.{
        .name = "re2",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libcpp = true,
        }),
    });
    re2_lib.addIncludePath(re2_dep.path("."));
    re2_lib.addIncludePath(abseil_dep.path("."));
    re2_lib.addCSourceFiles(.{
        .root = re2_dep.path("."),
        .files = &re2_sources,
        .flags = flags,
    });
    re2_lib.linkLibrary(abseil_lib);

    const re2_mod = b.addModule("re2", .{
        .root_source_file = b.path("src/lib/re2.zig"),
        .target = target,
        .optimize = optimize,
    });
    re2_mod.addIncludePath(b.path("src/re2_ffi"));

    // --- Docs ---

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

    // --- Tests ---

    const tests_root = b.createModule(.{
        .root_source_file = b.path("tests/suite.zig"),
        .target = target,
        .optimize = optimize,
    });
    tests_root.addImport("pcre2", pcre2_mod);
    tests_root.addImport("re2", re2_mod);

    const tests = b.addTest(.{
        .root_module = tests_root,
    });
    tests.addCSourceFile(.{
        .file = b.path("src/re2_ffi/re2_ffi.cpp"),
        .flags = &.{"-std=c++17"},
    });
    tests.linkLibCpp();
    tests.addIncludePath(b.path("src/re2_ffi"));
    tests.addIncludePath(re2_dep.path("."));
    tests.addIncludePath(abseil_dep.path("."));
    tests.linkLibrary(re2_lib);
    if (target.result.os.tag == .windows) {
        tests.linkSystemLibrary("dbghelp");
        tests.linkSystemLibrary("bcrypt");
    }

    const tests_step = b.step("tests", "Run the test suite");
    const run_tests = b.addRunArtifact(tests);
    tests_step.dependOn(&run_tests.step);
}
