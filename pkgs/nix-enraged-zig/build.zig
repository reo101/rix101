const std = @import("std");
const Translator = @import("translate_c").Translator;

const Backend = enum {
    cppnix,
    detsys,
};

const CacheMode = enum {
    stable,
    @"volatile",
    off,
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const backend = b.option(
        Backend,
        "backend",
        "Nix implementation to target (cppnix or detsys)",
    ) orelse .cppnix;
    const cache_mode = b.option(
        CacheMode,
        "cache-mode",
        "Plaintext cache policy (stable, volatile, or off)",
    ) orelse .@"volatile";
    const include_dirs = b.option(
        []const []const u8,
        "nix-include-dir",
        "Nix C API include directory; repeat for additional directories",
    ) orelse &.{};
    const library_dirs = b.option(
        []const []const u8,
        "nix-lib-dir",
        "Nix C API library directory; repeat for additional directories",
    ) orelse &.{};
    const rage = b.option(
        []const u8,
        "rage-exe",
        "Path to the rage executable",
    ) orelse "rage";

    const translate_c = b.dependency("translate_c", .{});
    const translate_target = b.resolveTargetQuery(std.Target.Query.fromTarget(&target.result));
    const c_api = Translator.init(translate_c, .{
        .c_source_file = b.path("src/c_api.h"),
        .target = translate_target,
        .optimize = optimize,
    });
    c_api.run.addArg("-std=c23");
    for (include_dirs) |dir| c_api.addIncludePath(.{ .cwd_relative = dir });

    const options = b.addOptions();
    options.addOption(Backend, "backend", backend);
    options.addOption(CacheMode, "cache_mode", cache_mode);
    options.addOption(
        [:0]const u8,
        "rage_exe",
        b.allocator.dupeZ(u8, rage) catch @panic("out of memory"),
    );

    const root = b.createModule(.{
        .root_source_file = b.path("src/plugin.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .pic = true,
        .strip = optimize != .Debug,
        .imports = &.{
            .{ .name = "c_api", .module = c_api.mod },
            .{ .name = "build_options", .module = options.createModule() },
        },
    });
    for (library_dirs) |dir| {
        const path: std.Build.LazyPath = .{ .cwd_relative = dir };
        root.addLibraryPath(path);
        root.addRPath(path);
    }
    root.linkSystemLibrary("nixexprc", .{
        .needed = true,
        .use_pkg_config = .no,
        .preferred_link_mode = .dynamic,
        .search_strategy = .paths_first,
    });

    const plugin = b.addLibrary(.{
        .name = "nix-enraged-zig",
        .linkage = .dynamic,
        .root_module = root,
    });
    b.installArtifact(plugin);
}
