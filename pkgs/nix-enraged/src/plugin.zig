const std = @import("std");
const c = @import("c_api");
const build_options = @import("build_options");

const allocator = std.heap.c_allocator;
const rage_exe = build_options.rage_exe;
const max_file_size_bytes = 16 * 1024 * 1024;

const cache_doc = switch (build_options.cache_mode) {
    .stable =>
    \\**Cache mode:** `stable`. Plaintext is cached persistently under
    \\`NIX_ENRAGED_CACHE_DIR`, `$XDG_CACHE_HOME/nix-enraged`, or
    \\`$HOME/.cache/nix-enraged`. Cache hits do not access identity files.
    ,
    .@"volatile" =>
    \\**Cache mode:** `volatile`. By default, plaintext is cached in
    \\reboot-cleared storage under `$XDG_RUNTIME_DIR/nix-enraged` or
    \\`/run/user/$UID/nix-enraged` (`/run/nix-enraged` for root), never `/tmp`.
    \\`NIX_ENRAGED_CACHE_DIR` explicitly overrides that root. Cache hits do not
    \\access identity files. When no runtime directory is usable (e.g. macOS,
    \\containers without `XDG_RUNTIME_DIR`), it degrades to the stable cache
    \\root instead of failing.
    ,
    .off =>
    \\**Cache mode:** `off`. Plaintext is streamed through a pipe and is never
    \\written to a cache or temporary plaintext file.
    ,
};

const rage_import_doc =
    \\**Synopsis:** `builtins.extraBuiltins.rageImportEncrypted identities encryptedFile`
    \\
    \\Decrypts `encryptedFile` with Rage and evaluates its plaintext as a Nix
    \\expression. `encryptedFile` must be a path ending in `.nix.age`.
    \\`identities` must be a list of strings or paths accepted by `rage -i`;
    \\store-backed values are realised before Rage runs.
    \\
    \\```nix
    \\builtins.extraBuiltins.rageImportEncrypted [
    \\  ./identity
    \\] ./secret.nix.age
    \\```
    \\
    \\`AGENIX_REKEY_PRIMARY_IDENTITY` adds a primary identity unless it is
    \\already present in the list. When `AGENIX_REKEY_PRIMARY_IDENTITY_ONLY` is
    \\true, the list is ignored and the primary identity is required.
    \\Interactive identities require a TTY on a cache miss. Plaintext is limited
    \\to 16 MiB.
    \\
    \\`NIX_ENRAGED_LOCK_WAIT_TIMEOUT` bounds how long to wait for a cache
    \\entry's lock (seconds, default 300); `NIX_ENRAGED_FAILURE_CACHE_TIMEOUT`
    \\debounces repeated decrypt failures for the same entry (seconds, default 30).
    \\
    \\The decrypted expression uses `/` as its base path; use absolute or
    \\store-backed paths for imports.
    \\
    \\
++ cache_doc;

fn reportError(ctx: ?*c.nix_c_context, err: anyerror) void {
    if (err == error.NixApi) return;
    _ = c.nix_set_err_msg(ctx, c.NIX_ERR_UNKNOWN, @errorName(err).ptr);
}

fn checkNix(result: c.nix_err) error{NixApi}!void {
    if (result != c.NIX_OK) return error.NixApi;
}

fn env(name: [*:0]const u8) ?[]const u8 {
    const value = std.c.getenv(name) orelse return null;
    if (value[0] == 0) return null;
    return std.mem.span(@as([*:0]const u8, @ptrCast(value)));
}

fn parseBool(value: ?[]const u8) !bool {
    const text = value orelse return false;
    if (text.len == 0 or std.mem.eql(u8, text, "0") or
        std.ascii.eqlIgnoreCase(text, "false") or
        std.ascii.eqlIgnoreCase(text, "no") or
        std.ascii.eqlIgnoreCase(text, "off")) return false;
    if (std.mem.eql(u8, text, "1") or
        std.ascii.eqlIgnoreCase(text, "true") or
        std.ascii.eqlIgnoreCase(text, "yes") or
        std.ascii.eqlIgnoreCase(text, "on")) return true;
    return error.InvalidPrimaryIdentityOnly;
}

fn valueToString(
    ctx: ?*c.nix_c_context,
    state: ?*c.EvalState,
    value: ?*c.nix_value,
) ![:0]u8 {
    try checkNix(c.nix_value_force(ctx, state, value));

    var temporary: ?*c.nix_value = null;
    defer {
        if (temporary) |v| _ = c.nix_value_decref(null, v);
    }

    const string_value = switch (c.nix_get_type(ctx, value)) {
        c.NIX_TYPE_STRING => value,
        c.NIX_TYPE_PATH => path: {
            const to_string = c.nix_alloc_value(ctx, state) orelse return error.NixApi;
            defer _ = c.nix_value_decref(null, to_string);
            temporary = c.nix_alloc_value(ctx, state) orelse return error.NixApi;
            try checkNix(c.nix_expr_eval_from_string(ctx, state, "builtins.toString", "/", to_string));
            try checkNix(c.nix_value_call(ctx, state, to_string, value, temporary));
            break :path temporary;
        },
        else => return error.ExpectedStringOrPath,
    };

    const realised = c.nix_string_realise(ctx, state, string_value, true) orelse
        return error.NixApi;
    defer c.nix_realised_string_free(realised);
    const start = c.nix_realised_string_get_buffer_start(realised);
    const size = c.nix_realised_string_get_buffer_size(realised);
    const string = try allocator.dupeZ(u8, start[0..size]);
    errdefer allocator.free(string);
    if (std.mem.indexOfScalar(u8, string, 0) != null) return error.NulInArgument;
    return string;
}

fn openReadOnly(io: std.Io, path: [:0]const u8, follow_symlinks: bool) !std.Io.File {
    return std.Io.Dir.cwd().openFile(io, path, .{
        .allow_directory = false,
        .follow_symlinks = follow_symlinks,
    });
}

fn readFileZ(io: std.Io, path: [:0]const u8, limit: usize, follow_symlinks: bool) ![:0]u8 {
    var file = try openReadOnly(io, path, follow_symlinks);
    defer file.close(io);

    var reader = file.reader(io, &.{});
    return reader.interface.allocRemainingAlignedSentinel(
        allocator,
        .limited(limit + 1),
        .of(u8),
        0,
    ) catch |err| switch (err) {
        error.StreamTooLong => error.PlaintextTooLarge,
        else => |other| other,
    };
}

fn hashFile(io: std.Io, path: [:0]const u8) ![std.crypto.hash.sha2.Sha512.digest_length]u8 {
    var file = try openReadOnly(io, path, false);
    defer file.close(io);

    var hasher = std.crypto.hash.sha2.Sha512.init(.{});
    var buffer: [8192]u8 = undefined;
    var offset: u64 = 0;
    while (true) {
        const count = try file.readPositional(io, &.{&buffer}, offset);
        if (count == 0) break;
        hasher.update(buffer[0..count]);
        offset += @intCast(count);
    }
    var digest: [std.crypto.hash.sha2.Sha512.digest_length]u8 = undefined;
    hasher.final(&digest);
    return digest;
}

fn mkdirp(io: std.Io, path: [:0]const u8) !void {
    const cwd = std.Io.Dir.cwd();
    _ = cwd.createDirPathStatus(io, path, .fromMode(0o700)) catch
        return error.CreateCacheDirectoryFailed;
    cwd.setFilePermissions(io, path, .fromMode(0o700), .{}) catch
        return error.SecureCacheDirectoryFailed;
}

fn isUsableDirectory(io: std.Io, path: []const u8) bool {
    const cwd = std.Io.Dir.cwd();
    const stat = cwd.statFile(io, path, .{}) catch return false;
    if (stat.kind != .directory) return false;
    cwd.access(io, path, .{ .write = true, .execute = true }) catch return false;
    return true;
}

fn absoluteEnv(name: [*:0]const u8) ?[]const u8 {
    const value = env(name) orelse return null;
    return if (std.fs.path.isAbsolute(value)) value else null;
}

fn cachePath(base: []const u8) ![:0]u8 {
    return std.fmt.allocPrintSentinel(allocator, "{s}/nix-enraged", .{base}, 0);
}

fn stableCacheRoot() ![:0]u8 {
    if (absoluteEnv("XDG_CACHE_HOME")) |base| return cachePath(base);
    if (absoluteEnv("HOME")) |home| {
        return std.fmt.allocPrintSentinel(allocator, "{s}/.cache/nix-enraged", .{home}, 0);
    }
    return error.StableCacheDirectoryUnavailable;
}

fn volatileCacheRoot(io: std.Io) ![:0]u8 {
    if (absoluteEnv("XDG_RUNTIME_DIR")) |base| {
        if (isUsableDirectory(io, base)) return cachePath(base);
    }

    const uid = std.c.getuid();
    const base = try std.fmt.allocPrintSentinel(allocator, "/run/user/{d}", .{uid}, 0);
    defer allocator.free(base);
    if (isUsableDirectory(io, base)) return cachePath(base);
    if (uid == 0 and isUsableDirectory(io, "/run")) return cachePath("/run");
    // No usable runtime dir (macOS, headless/containers without
    // XDG_RUNTIME_DIR): degrade to the stable cache root so decryption
    // keeps working rather than hard-failing. Never falls back to /tmp.
    return stableCacheRoot();
}

fn cacheRoot(io: std.Io) ![:0]u8 {
    if (env("NIX_ENRAGED_CACHE_DIR")) |root| return allocator.dupeZ(u8, root);
    return switch (comptime build_options.cache_mode) {
        .stable => stableCacheRoot(),
        .@"volatile" => volatileCacheRoot(io),
        .off => unreachable,
    };
}

fn fileSize(io: std.Io, path: [:0]const u8) !u64 {
    var file = try openReadOnly(io, path, false);
    defer file.close(io);
    return file.length(io);
}

fn nonEmpty(io: std.Io, path: [:0]const u8) bool {
    return (fileSize(io, path) catch return false) > 0;
}

/// Parses a `NIX_ENRAGED_*` timeout env var as whole seconds.
/// Missing/empty falls back to `default`; anything non-numeric is rejected
/// (mirrors the shell wrapper's `die`).
fn parseTimeout(name: [*:0]const u8, default: u64) !u64 {
    const value = env(name) orelse return default;
    return std.fmt.parseInt(u64, value, 10) catch error.InvalidTimeout;
}

/// Acquires the cache entry's exclusive lock, bounding the wait with a
/// monotonic deadline (CLOCK_MONOTONIC — immune to wall-clock jumps, matching
/// `flock -w`). `timeout_seconds == 0` fails immediately, like `flock -w 0`.
fn acquireLock(io: std.Io, lock: std.Io.File, timeout_seconds: u64) !void {
    const Clock = std.Io.Clock;

    if (timeout_seconds == 0) {
        if (!try lock.tryLock(io, .exclusive)) return error.LockWaitTimedOut;
        return;
    }

    const deadline = Clock.Timestamp.fromNow(io, .{
        .raw = .{ .nanoseconds = @as(i96, @intCast(timeout_seconds)) * std.time.ns_per_s },
        .clock = .awake,
    });
    while (true) {
        if (try lock.tryLock(io, .exclusive)) return;
        if (Clock.Timestamp.now(io, .awake).compare(.gte, deadline))
            return error.LockWaitTimedOut;
        Clock.Duration.sleep(
            .{ .raw = .{ .nanoseconds = 25 * std.time.ns_per_ms }, .clock = .awake },
            io,
        ) catch return error.LockWaitTimedOut;
    }
}

/// Reads the `<out>.failed` marker, returning the recorded failure `rc` iff it
/// is still within the debounce window. Any malformed/stale marker is treated
/// as absent so the entry gets retried. Mirrors the shell's
/// `failed_at failed_rc` + `now - failed_at < failure_timeout` logic.
fn cachedFailure(io: std.Io, failure_path: [:0]const u8, failure_timeout: u64) !?u32 {
    var file = openReadOnly(io, failure_path, false) catch |err| switch (err) {
        error.FileNotFound => return null,
        else => return err,
    };
    defer file.close(io);

    var buf: [64]u8 = undefined;
    const n = file.readPositionalAll(io, &buf, 0) catch return null;
    const contents = std.mem.trim(u8, buf[0..n], " \t\r\n");
    var it = std.mem.splitScalar(u8, contents, ' ');
    const failed_at = std.fmt.parseInt(u64, it.next() orelse return null, 10) catch return null;
    const failed_rc = std.fmt.parseInt(u32, it.next() orelse return null, 10) catch return null;
    if (failed_rc == 0) return null;

    const now: u64 = epochSeconds(io);
    if (now >= failed_at and now - failed_at < failure_timeout) return failed_rc;
    return null;
}

/// Wall-clock epoch seconds via the Io real clock (shell `date +%s` equivalent).
fn epochSeconds(io: std.Io) u64 {
    const ns = std.Io.Clock.Timestamp.now(io, .real).raw.nanoseconds;
    return @intCast(@divTrunc(ns, std.time.ns_per_s));
}

/// Writes the `<out>.failed` marker: `<epoch> <rc>`. Best-effort, like the
/// shell's `printf ... > "$failure_file"` under the lock.
fn recordFailure(io: std.Io, failure_path: [:0]const u8, failed_rc: u32) void {
    const cwd = std.Io.Dir.cwd();
    const data = std.fmt.allocPrint(allocator, "{d} {d}\n", .{ epochSeconds(io), failed_rc }) catch return;
    defer allocator.free(data);
    cwd.writeFile(io, .{
        .sub_path = failure_path,
        .data = data,
        .flags = .{ .truncate = true, .permissions = .fromMode(0o600) },
    }) catch {};
}

fn needsInteractiveInput(io: std.Io, path: [:0]const u8) bool {
    const contents = readFileZ(io, path, max_file_size_bytes, true) catch return false;
    defer {
        std.crypto.secureZero(u8, contents);
        allocator.free(contents);
    }
    return std.mem.indexOf(u8, contents, "AGE-PLUGIN-YUBIKEY-") != null or
        std.mem.indexOf(u8, contents, "-> scrypt ") != null;
}

fn rejectInteractiveIdentities(
    io: std.Io,
    identities: []const [:0]u8,
    primary: ?[:0]const u8,
) !void {
    if (std.Io.File.stdin().isTty(io) catch false) return;
    if (primary) |identity| {
        if (needsInteractiveInput(io, identity)) return error.NonInteractiveIdentity;
    }
    for (identities) |identity| {
        if (needsInteractiveInput(io, identity)) return error.NonInteractiveIdentity;
    }
}

fn rageArgs(
    encrypted_file: [:0]const u8,
    output_file: ?[:0]const u8,
    identities: []const [:0]u8,
    primary: ?[:0]const u8,
) !std.ArrayList([:0]const u8) {
    var args: std.ArrayList([:0]const u8) = .empty;
    errdefer args.deinit(allocator);
    try args.append(allocator, rage_exe);
    try args.append(allocator, "-d");
    if (primary) |identity| {
        try args.append(allocator, "-i");
        try args.append(allocator, identity);
    }
    for (identities) |identity| {
        try args.append(allocator, "-i");
        try args.append(allocator, identity);
    }
    if (output_file) |output| {
        try args.append(allocator, "-o");
        try args.append(allocator, output);
    }
    try args.append(allocator, encrypted_file);
    return args;
}

fn spawnRage(
    args: []const [:0]const u8,
    file_actions: [*c]const c.posix_spawn_file_actions_t,
) !c.pid_t {
    const argv = try allocator.alloc(?[*:0]u8, args.len + 1);
    defer allocator.free(argv);
    for (args, 0..) |arg, index| argv[index] = @constCast(arg.ptr);
    argv[args.len] = null;

    // NOTE: `posix_spawnp` keeps process-runtime ownership out of Nix
    var pid: c.pid_t = undefined;
    const spawn_result = c.posix_spawnp(
        &pid,
        rage_exe,
        file_actions,
        null,
        @ptrCast(argv.ptr),
        @ptrCast(std.c.environ),
    );
    if (spawn_result != 0) return error.SpawnRageFailed;
    return pid;
}

fn reapRage(pid: c.pid_t) !c_int {
    var status: c_int = undefined;
    while (c.waitpid(pid, &status, 0) < 0) {
        if (std.c.errno(-1) == .INTR) continue;
        return error.WaitForRageFailed;
    }
    return status;
}

fn checkRageStatus(status: c_int) !void {
    if (!c.WIFEXITED(status) or c.WEXITSTATUS(status) != 0) return error.RageFailed;
}

fn terminateAndReap(pid: c.pid_t) void {
    _ = c.kill(pid, c.SIGKILL);
    while (c.waitpid(pid, null, 0) < 0) {
        if (std.c.errno(-1) != .INTR) break;
    }
}

fn runRage(
    encrypted_file: [:0]const u8,
    output_file: [:0]const u8,
    identities: []const [:0]u8,
    primary: ?[:0]const u8,
) !void {
    var args = try rageArgs(encrypted_file, output_file, identities, primary);
    defer args.deinit(allocator);
    const pid = try spawnRage(args.items, null);
    try checkRageStatus(try reapRage(pid));
}

fn decryptWithoutCache(
    io: std.Io,
    encrypted_file: [:0]const u8,
    identities: []const [:0]u8,
    primary: ?[:0]const u8,
) ![:0]u8 {
    try rejectInteractiveIdentities(io, identities, primary);

    const pipe = try std.Io.Threaded.pipe2(.{ .CLOEXEC = true });
    var read_open = true;
    defer if (read_open) std.Io.Threaded.closeFd(pipe[0]);
    var write_open = true;
    defer if (write_open) std.Io.Threaded.closeFd(pipe[1]);

    var actions: c.posix_spawn_file_actions_t = undefined;
    if (c.posix_spawn_file_actions_init(&actions) != 0)
        return error.ConfigureRagePipeFailed;
    defer _ = c.posix_spawn_file_actions_destroy(&actions);
    if (c.posix_spawn_file_actions_addclose(&actions, pipe[0]) != 0)
        return error.ConfigureRagePipeFailed;
    if (pipe[1] != c.STDOUT_FILENO) {
        if (c.posix_spawn_file_actions_adddup2(&actions, pipe[1], c.STDOUT_FILENO) != 0)
            return error.ConfigureRagePipeFailed;
        if (c.posix_spawn_file_actions_addclose(&actions, pipe[1]) != 0)
            return error.ConfigureRagePipeFailed;
    }

    var args = try rageArgs(encrypted_file, null, identities, primary);
    defer args.deinit(allocator);
    const pid = try spawnRage(args.items, &actions);
    var child_running = true;
    defer if (child_running) terminateAndReap(pid);

    std.Io.Threaded.closeFd(pipe[1]);
    write_open = false;
    var output: std.Io.File = .{
        .handle = pipe[0],
        .flags = .{ .nonblocking = false },
    };
    read_open = false;
    defer output.close(io);

    var reader = output.reader(io, &.{});
    const plaintext = reader.interface.allocRemainingAlignedSentinel(
        allocator,
        .limited(max_file_size_bytes + 1),
        .of(u8),
        0,
    ) catch |err| switch (err) {
        error.StreamTooLong => return error.PlaintextTooLarge,
        else => |other| return other,
    };
    errdefer {
        std.crypto.secureZero(u8, plaintext);
        allocator.free(plaintext);
    }

    const status = try reapRage(pid);
    child_running = false;
    try checkRageStatus(status);
    if (plaintext.len == 0) return error.EmptyPlaintext;
    return plaintext;
}

fn decryptAndCache(
    io: std.Io,
    encrypted_file: [:0]const u8,
    identities: []const [:0]u8,
    primary: ?[:0]const u8,
) ![:0]u8 {
    const cwd = std.Io.Dir.cwd();
    const root = try cacheRoot(io);
    defer allocator.free(root);
    try mkdirp(io, root);

    const digest = try hashFile(io, encrypted_file);
    const hex = std.fmt.bytesToHex(digest, .lower);
    const output = try std.fmt.allocPrintSentinel(allocator, "{s}/{s}.nix", .{ root, hex[0..32] }, 0);
    defer allocator.free(output);

    if (!nonEmpty(io, output)) {
        const lock_path = try std.fmt.allocPrintSentinel(allocator, "{s}.lock", .{output}, 0);
        defer allocator.free(lock_path);
        const failure_path = try std.fmt.allocPrintSentinel(allocator, "{s}.failed", .{output}, 0);
        defer allocator.free(failure_path);

        const lock_timeout = try parseTimeout("NIX_ENRAGED_LOCK_WAIT_TIMEOUT", 300);
        const failure_timeout = try parseTimeout("NIX_ENRAGED_FAILURE_CACHE_TIMEOUT", 30);

        var lock = cwd.createFile(io, lock_path, .{
            .read = true,
            .truncate = false,
            .permissions = .fromMode(0o600),
        }) catch return error.OpenCacheLockFailed;
        defer lock.close(io);
        try acquireLock(io, lock, lock_timeout);

        if (!nonEmpty(io, output)) {
            // A still-fresh `.failed` marker means a recent decrypt failed;
            // fail fast instead of re-running rage (and re-triggering a
            // YubiKey/passphrase prompt) N times for N concurrent waiters.
            if (try cachedFailure(io, failure_path, failure_timeout)) |_| {
                return error.RageFailed;
            }
            cwd.deleteFile(io, failure_path) catch {};

            try rejectInteractiveIdentities(io, identities, primary);

            const temporary = try std.fmt.allocPrintSentinel(allocator, "{s}.tmp.XXXXXX", .{output}, 0);
            defer allocator.free(temporary);
            const temporary_fd = c.mkstemp(temporary.ptr);
            if (temporary_fd < 0) return error.CreateTemporaryFileFailed;
            const temporary_file: std.Io.File = .{
                .handle = temporary_fd,
                .flags = .{ .nonblocking = false },
            };
            temporary_file.close(io);
            var keep_temporary = true;
            defer if (keep_temporary) cwd.deleteFile(io, temporary) catch {};

            runRage(encrypted_file, temporary, identities, primary) catch |err| {
                recordFailure(io, failure_path, 1);
                return err;
            };
            const plaintext_size = try fileSize(io, temporary);
            if (plaintext_size == 0) {
                recordFailure(io, failure_path, 1);
                return error.EmptyPlaintext;
            }
            if (plaintext_size > max_file_size_bytes) {
                recordFailure(io, failure_path, 1);
                return error.PlaintextTooLarge;
            }
            cwd.setFilePermissions(
                io,
                temporary,
                .fromMode(0o600),
                .{ .follow_symlinks = false },
            ) catch return error.SecurePlaintextFailed;
            cwd.rename(temporary, cwd, output, io) catch
                return error.CachePlaintextFailed;
            keep_temporary = false;
            // Success: clear the failure marker so the next waiter retries.
            cwd.deleteFile(io, failure_path) catch {};
        } else {
            // Cached plaintext is authoritative; drop any stale marker.
            cwd.deleteFile(io, failure_path) catch {};
        }
    }

    return readFileZ(io, output, max_file_size_bytes, false);
}

fn rageImportEncrypted(
    user_data: ?*anyopaque,
    ctx: ?*c.nix_c_context,
    state: ?*c.EvalState,
    args: [*c]?*c.nix_value,
    result: ?*c.nix_value,
) callconv(.c) void {
    _ = user_data;

    const io = std.Io.Threaded.global_single_threaded.io();
    const plaintext = rageImportEncryptedImpl(io, ctx, state, args) catch |err|
        return reportError(ctx, err);
    defer {
        std.crypto.secureZero(u8, plaintext);
        allocator.free(plaintext);
    }
    if (std.mem.indexOfScalar(u8, plaintext, 0) != null)
        return reportError(ctx, error.NulInPlaintext);
    _ = c.nix_expr_eval_from_string(ctx, state, plaintext.ptr, "/", result);
}

fn rageImportEncryptedImpl(
    io: std.Io,
    ctx: ?*c.nix_c_context,
    state: ?*c.EvalState,
    args: [*c]?*c.nix_value,
) ![:0]u8 {
    try checkNix(c.nix_value_force(ctx, state, args[0]));
    if (c.nix_get_type(ctx, args[0]) != c.NIX_TYPE_LIST) return error.ExpectedIdentityList;
    try checkNix(c.nix_value_force(ctx, state, args[1]));
    if (c.nix_get_type(ctx, args[1]) != c.NIX_TYPE_PATH) return error.ExpectedEncryptedPath;

    const encrypted_file = try valueToString(ctx, state, args[1]);
    defer allocator.free(encrypted_file);
    if (!std.mem.endsWith(u8, encrypted_file, ".nix.age")) return error.ExpectedNixAgeSuffix;

    const primary_only = try parseBool(env("AGENIX_REKEY_PRIMARY_IDENTITY_ONLY"));
    const primary_env = env("AGENIX_REKEY_PRIMARY_IDENTITY");
    if (primary_only and primary_env == null) return error.PrimaryIdentityMissing;
    const primary_owned = if (primary_env) |identity| try allocator.dupeZ(u8, identity) else null;
    defer if (primary_owned) |identity| allocator.free(identity);

    var identities: std.ArrayList([:0]u8) = .empty;
    defer {
        for (identities.items) |identity| allocator.free(identity);
        identities.deinit(allocator);
    }
    if (!primary_only) {
        const count = c.nix_get_list_size(ctx, args[0]);
        try identities.ensureTotalCapacity(allocator, count);
        for (0..count) |index| {
            const value = c.nix_get_list_byidx(ctx, args[0], state, @intCast(index)) orelse
                return error.NixApi;
            defer _ = c.nix_value_decref(null, value);
            try identities.append(allocator, try valueToString(ctx, state, value));
        }
    }

    var primary: ?[:0]const u8 = null;
    if (primary_owned) |candidate| {
        const duplicate =
            for (identities.items) |identity| {
                if (std.mem.eql(u8, candidate, identity)) break true;
            } else false;
        if (primary_only or !duplicate) primary = candidate;
    }

    return switch (comptime build_options.cache_mode) {
        .stable, .@"volatile" => decryptAndCache(io, encrypted_file, identities.items, primary),
        .off => decryptWithoutCache(io, encrypted_file, identities.items, primary),
    };
}

fn extraBuiltins(
    user_data: ?*anyopaque,
    ctx: ?*c.nix_c_context,
    state: ?*c.EvalState,
    args: [*c]?*c.nix_value,
    result: ?*c.nix_value,
) callconv(.c) void {
    _ = user_data;
    _ = args;

    const primop = c.nix_alloc_primop(
        ctx,
        rageImportEncrypted,
        2,
        "rageImportEncrypted",
        // NOTE: `Nix`'s automatic `PrimOp` synopsis assumes `builtins.<name>`
        null,
        rage_import_doc,
        null,
    ) orelse return;
    defer _ = c.nix_gc_decref(null, primop);

    const value = c.nix_alloc_value(ctx, state) orelse return;
    defer _ = c.nix_value_decref(null, value);
    if (c.nix_init_primop(ctx, value, primop) != c.NIX_OK) return;

    const attrs = c.nix_make_bindings_builder(ctx, state, 1) orelse return;
    defer c.nix_bindings_builder_free(attrs);
    if (c.nix_bindings_builder_insert(ctx, attrs, "rageImportEncrypted", value) != c.NIX_OK) return;
    _ = c.nix_make_attrs(ctx, result, attrs);
}

export fn nix_plugin_entry() callconv(.c) void {
    const ctx = c.nix_c_context_create() orelse c.abort();
    defer c.nix_c_context_free(ctx);
    const primop = c.nix_alloc_primop(
        ctx,
        extraBuiltins,
        0,
        "__extraBuiltins",
        null,
        "Extra builtins supplied by nix-enraged (" ++ @tagName(build_options.backend) ++
            ", cache=" ++ @tagName(build_options.cache_mode) ++ ").",
        null,
    ) orelse c.abort();
    if (c.nix_register_primop(ctx, primop) != c.NIX_OK) c.abort();
    _ = c.nix_gc_decref(null, primop);
}
