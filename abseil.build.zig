const std = @import("std");

const base_sources = .{
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

const container_sources = .{
    "internal/hashtablez_sampler.cc",
    "internal/hashtablez_sampler_force_weak_definition.cc",
    "internal/raw_hash_set.cc",
};

const hash_sources = .{
    "internal/hash.cc",
    "internal/city.cc",
};

const numeric_sources = .{
    "int128.cc",
};

const strings_sources = .{
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

const synchronization_sources = .{
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
    "notification.cc",
    "mutex.cc",
};

const synchronization_windows_sources = .{
    "internal/win32_waiter.cc",
};

const status_sources = .{
    "internal/status_internal.cc",
    "status.cc",
    "status_payload_printer.cc",
    "statusor.cc",
};

const crc_sources = .{
    "crc32c.cc",
    "internal/cpu_detect.cc",
    "internal/crc.cc",
    "internal/crc_cord_state.cc",
    "internal/crc_memcpy_fallback.cc",
    "internal/crc_memcpy_x86_arm_combined.cc",
    "internal/crc_non_temporal_memcpy.cc",
    "internal/crc_x86_arm_combined.cc",
};

const debugging_sources = .{
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

const time_sources = .{
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
};

const time_windows_sources = .{
    "internal/cctz/src/time_zone_name_win.cc",
};

const log_sources = .{
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

const flags_sources = .{
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

const profiling_sources = .{
    "internal/exponential_biased.cc",
    "internal/periodic_sampler.cc",
};

const random_sources = .{
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

pub fn build(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Step.Compile {
    const dep = b.dependency("abseil", .{
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
        .name = "abseil",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libcpp = true,
        }),
    });

    if (target.result.os.tag == .windows) {
        lib.root_module.linkSystemLibrary("dbghelp", .{});
        lib.root_module.linkSystemLibrary("bcrypt", .{});
    }

    if (target.result.os.tag == .macos) {
        lib.root_module.linkFramework("CoreFoundation", .{});
    }

    lib.root_module.addIncludePath(dep.path("."));
    lib.root_module.addCSourceFiles(.{
        .root = dep.path("absl/base"),
        .files = &base_sources,
        .flags = flags,
    });

    lib.root_module.addCSourceFiles(.{
        .root = dep.path("absl/container"),
        .files = &container_sources,
        .flags = flags,
    });

    lib.root_module.addCSourceFiles(.{
        .root = dep.path("absl/hash"),
        .files = &hash_sources,
        .flags = flags,
    });

    lib.root_module.addCSourceFiles(.{
        .root = dep.path("absl/numeric"),
        .files = &numeric_sources,
        .flags = flags,
    });

    lib.root_module.addCSourceFiles(.{
        .root = dep.path("absl/strings"),
        .files = &strings_sources,
        .flags = flags,
    });

    lib.root_module.addCSourceFiles(.{
        .root = dep.path("absl/synchronization"),
        .files = &synchronization_sources,
        .flags = flags,
    });

    if (target.result.os.tag == .windows) {
        lib.root_module.addCSourceFiles(.{
            .root = dep.path("absl/synchronization"),
            .files = &synchronization_windows_sources,
            .flags = flags,
        });
    }

    lib.root_module.addCSourceFiles(.{
        .root = dep.path("absl/status"),
        .files = &status_sources,
        .flags = flags,
    });

    lib.root_module.addCSourceFiles(.{
        .root = dep.path("absl/crc"),
        .files = &crc_sources,
        .flags = flags,
    });

    lib.root_module.addCSourceFiles(.{
        .root = dep.path("absl/debugging"),
        .files = &debugging_sources,
        .flags = flags,
    });

    lib.root_module.addCSourceFiles(.{
        .root = dep.path("absl/time"),
        .files = &time_sources,
        .flags = flags,
    });

    if (target.result.os.tag == .windows) {
        lib.root_module.addCSourceFiles(.{
            .root = dep.path("absl/time"),
            .files = &time_windows_sources,
            .flags = flags,
        });
    }

    lib.root_module.addCSourceFiles(.{
        .root = dep.path("absl/log"),
        .files = &log_sources,
        .flags = flags,
    });

    lib.root_module.addCSourceFiles(.{
        .root = dep.path("absl/flags"),
        .files = &flags_sources,
        .flags = flags,
    });

    lib.root_module.addCSourceFiles(.{
        .root = dep.path("absl/profiling"),
        .files = &profiling_sources,
        .flags = flags,
    });

    lib.root_module.addCSourceFiles(.{
        .root = dep.path("absl/random"),
        .files = &random_sources,
        .flags = flags,
    });

    return lib;
}
