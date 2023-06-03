const std = @import("std");

pub fn build(b: *std.build.Builder) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const enable_compression = b.option(bool, "ZSTD_LIB_COMPRESSION", "Enable compression API (default: true)") orelse true;
    const enable_decompression = b.option(bool, "ZSTD_LIB_DECOMPRESSION", "Enable decompression API (default: true)") orelse true;
    const enable_dictbuilder = b.option(bool, "ZSTD_LIB_DICTBUILDER", "Enable dictbuilder API. Requires ZSTD_LIB_COMPRESSION. (default: true)") orelse true;

    if (enable_dictbuilder and !enable_compression) {
        std.debug.print("Error: ZSTD_LIB_DICTBUILDER requires ZSTD_LIB_COMPRESSION\n", .{});
        return error.InvalidOptions;
    }

    const lib = b.addStaticLibrary(.{
        .name = "zstd",
        .target = target,
        .optimize = optimize,
    });
    lib.linkLibC();
    lib.addIncludePath("lib");
    lib.addIncludePath("lib/legacy");
    lib.addCSourceFiles(&common_sources, &.{});
    lib.installHeadersDirectoryOptions(.{
        .source_dir = "lib/legacy",
        .install_dir = .header,
        .install_subdir = "",
        .exclude_extensions = &.{
            ".c",
        },
    });
    lib.installHeadersDirectoryOptions(.{
        .source_dir = "lib",
        .install_dir = .header,
        .install_subdir = "",
        .exclude_extensions = &.{
            "LICENSE",
            "Makefile",
            ".c",
            ".in",
        },
    });
    if (enable_compression) {
        lib.addCSourceFiles(&compress_sources, &.{});
    }
    if (enable_decompression) {
        lib.addAssemblyFile("lib/decompress/huf_decompress_amd64.S");
        lib.addCSourceFiles(&decompress_sources, &.{});
    }
    if (enable_dictbuilder) {
        lib.addCSourceFiles(&dictbuilder_sources, &.{});
    }
    b.installArtifact(lib);

    const zstdcli = b.addExecutable(.{
        .name = "zstd-cli",
        .target = target,
        .optimize = optimize,
    });
    zstdcli.linkLibrary(lib);
    zstdcli.addCSourceFiles(&cli_sources, &.{});
    b.installArtifact(zstdcli);

    const run = b.addRunArtifact(zstdcli);
    if (b.args) |args| {
        run.addArgs(args);
    }

    const run_step = b.step("run", "Run the zstd cli program");
    run_step.dependOn(&run.step);
}

const cli_sources = [_][]const u8{
    "programs/benchfn.c",
    "programs/benchzstd.c",
    "programs/datagen.c",
    "programs/dibio.c",
    "programs/fileio.c",
    "programs/fileio_asyncio.c",
    "programs/timefn.c",
    "programs/util.c",
    "programs/zstdcli.c",
    "programs/zstdcli_trace.c",
};

const common_sources = [_][]const u8{
    "lib/common/debug.c",
    "lib/common/entropy_common.c",
    "lib/common/error_private.c",
    "lib/common/fse_decompress.c",
    "lib/common/pool.c",
    "lib/common/threading.c",
    "lib/common/xxhash.c",
    "lib/common/zstd_common.c",
};

const compress_sources = [_][]const u8{
    "lib/compress/fse_compress.c",
    "lib/compress/hist.c",
    "lib/compress/huf_compress.c",
    "lib/compress/zstd_compress.c",
    "lib/compress/zstd_compress_literals.c",
    "lib/compress/zstd_compress_sequences.c",
    "lib/compress/zstd_compress_superblock.c",
    "lib/compress/zstd_double_fast.c",
    "lib/compress/zstd_fast.c",
    "lib/compress/zstd_lazy.c",
    "lib/compress/zstd_ldm.c",
    "lib/compress/zstd_opt.c",
    "lib/compress/zstdmt_compress.c",
};

const decompress_sources = [_][]const u8{
    "lib/decompress/huf_decompress.c",
    "lib/decompress/zstd_ddict.c",
    "lib/decompress/zstd_decompress.c",
    "lib/decompress/zstd_decompress_block.c",
};

const dictbuilder_sources = [_][]const u8{
    "lib/dictBuilder/cover.c",
    "lib/dictBuilder/divsufsort.c",
    "lib/dictBuilder/fastcover.c",
    "lib/dictBuilder/zdict.c",
};

const deprecated_sources = [_][]const u8{
    "lib/deprecated/zbuff_common.c",
    "lib/deprecated/zbuff_compress.c",
    "lib/deprecated/zbuff_decompress.c",
};
