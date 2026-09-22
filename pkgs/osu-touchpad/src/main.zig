//! osu-touchpad — Framework 16 touchpad -> absolute-position uinput pointer.
//!
//! Architecture (all below the compositor, fully Wayland-native):
//!
//!   physical touchpad -> evdev reader (multitouch Type B, primary slot only)
//!        -> coordinate transform (crop / aspect / clamp)
//!        -> uinput virtual absolute device (EV_ABS ABS_X/ABS_Y + BTN_LEFT)
//!        -> libinput -> niri -> wl_pointer -> osu!lazer
//!
//! The virtual device is udev-tagged as a plain mouse (BTN_LEFT, no pen, no
//! BTN_TOUCH), so libinput classifies it as a pointer and its fallback
//! dispatcher turns ABS_X/ABS_Y into POINTER_MOTION_ABSOLUTE events (the
//! accel init path requires REL_X/REL_Y, so an abs-only device is never
//! accelerated). Niri's on_pointer_motion_absolute maps that onto the output.
//!
//! Only the multitouch slot machinery is used for finger lifecycle; the
//! legacy single-contact ABS_X/ABS_Y stream is deliberately ignored (the
//! kernel's mirror of it is not guaranteed to track a specific slot).
const std = @import("std");

// ---------------------------------------------------------------------------
// libc surface (glibc ABI, stable across zig versions)
// ---------------------------------------------------------------------------

extern fn open(path: [*:0]const u8, flags: c_int, ...) c_int;
extern fn close(fd: c_int) c_int;
extern fn read(fd: c_int, buf: [*]u8, count: usize) isize;
extern fn write(fd: c_int, buf: [*]const u8, count: usize) isize;
extern fn ioctl(fd: c_int, request: u32, ...) c_int;
extern fn poll(fds: [*c]PollFd, nfds: c_ulong, timeout_ms: c_int) c_int;
extern fn getpid() c_int;
extern fn gettimeofday(tv: *TimeVal, tz: ?*anyopaque) c_int;
extern fn nanosleep(req: *const TimeSpec, rem: ?*TimeSpec) c_int;
extern fn signal(sig: c_int, handler: ?*const fn (c_int) callconv(.c) void) ?*anyopaque;
extern fn opendir(path: [*:0]const u8) ?*DirHandle;
extern fn readdir(h: *DirHandle) ?*const Dirent;
extern fn closedir(h: *DirHandle) c_int;
extern fn popen(command: [*:0]const u8, mode: [*:0]const u8) ?*anyopaque;
extern fn pclose(stream: ?*anyopaque) c_int;
extern fn fread(ptr: [*]u8, size: usize, nmemb: usize, stream: ?*anyopaque) usize;
extern fn __errno_location() *c_int;

const DirHandle = opaque {};

const TimeVal = extern struct { sec: i64, usec: i64 };
const TimeSpec = extern struct { sec: i64, nsec: i64 };
const PollFd = extern struct { fd: c_int, events: i16, revents: i16 };
// glibc struct dirent on 64-bit linux
const Dirent = extern struct {
    d_ino: u64,
    d_off: i64,
    d_reclen: u16,
    d_type: u8,
    d_name: [256]u8,
};

// ---------------------------------------------------------------------------
// kernel input ABI
// ---------------------------------------------------------------------------

const InputEvent = extern struct {
    sec: u64,
    usec: u64,
    type: u16,
    code: i16,
    value: i32,
};
const InputId = extern struct { bustype: u16, vendor: u16, product: u16, version: u16 };
const UinputSetup = extern struct { id: InputId, name: [80]u8, ff_effects_max: u32 };
const InputAbsInfo = extern struct {
    value: i32,
    minimum: i32,
    maximum: i32,
    fuzz: i32,
    flat: i32,
    resolution: i32,
};
const UinputAbsSetup = extern struct { code: u16, absinfo: InputAbsInfo };

comptime {
    std.debug.assert(@sizeOf(InputEvent) == 24);
    std.debug.assert(@sizeOf(InputId) == 8);
    std.debug.assert(@sizeOf(UinputSetup) == 92);
    std.debug.assert(@sizeOf(InputAbsInfo) == 24);
    std.debug.assert(@sizeOf(UinputAbsSetup) == 28);
}

const EV_SYN: u16 = 0x00;
const EV_KEY: u16 = 0x01;
const EV_ABS: u16 = 0x03;
const SYN_REPORT: i16 = 0;

const ABS_X: i16 = 0x00;
const ABS_Y: i16 = 0x01;
const ABS_MT_SLOT: i16 = 0x2f;
const ABS_MT_POSITION_X: i16 = 0x35;
const ABS_MT_POSITION_Y: i16 = 0x36;
const ABS_MT_TRACKING_ID: i16 = 0x39;

const BTN_LEFT: i16 = 0x110;

const O_RDONLY: c_int = 0;
const O_WRONLY: c_int = 1;
const O_NONBLOCK: c_int = 0o4000;
const POLLIN: i16 = 0x001;
const POLLERR_: i16 = 0x008;
const POLLHUP_: i16 = 0x010;
const POLLNVAL_: i16 = 0x020;
const EINTR: c_int = 4;
const EAGAIN: c_int = 11;
const ENODEV: c_int = 19;

const SIGINT_: c_int = 2;
const SIGTERM_: c_int = 15;

// asm-generic _IOC encoding (x86_64)
const IOC_WRITE: u32 = 1;
const IOC_READ: u32 = 2;
fn ioc(dir: u32, typ: u8, nr: u8, size: u32) u32 {
    return (dir << 30) | (size << 16) | (@as(u32, typ) << 8) | nr;
}
fn iow(typ: u8, nr: u8, size: u32) u32 {
    return ioc(IOC_WRITE, typ, nr, size);
}
fn ior(typ: u8, nr: u8, size: u32) u32 {
    return ioc(IOC_READ, typ, nr, size);
}
fn ioo(typ: u8, nr: u8) u32 {
    return ioc(0, typ, nr, 0);
}

// linux/uinput.h
const UI_DEV_CREATE: u32 = ioo('U', 1);
const UI_DEV_DESTROY: u32 = ioo('U', 2);
const UI_SET_EVBIT: u32 = iow('U', 100, @sizeOf(c_int));
const UI_SET_KEYBIT: u32 = iow('U', 101, @sizeOf(c_int));
const UI_SET_ABSBIT: u32 = iow('U', 103, @sizeOf(c_int));
const UI_DEV_SETUP: u32 = iow('U', 3, @sizeOf(UinputSetup));
const UI_ABS_SETUP: u32 = iow('U', 4, @sizeOf(UinputAbsSetup));

// linux/input.h
const EVIOCGRAB: u32 = iow('E', 0x90, @sizeOf(c_int));
fn eviocgname(len: u32) u32 {
    return ior('E', 0x06, len);
}
fn eviocgabs(abs: i16) u32 {
    return ior('E', 0x40 + @as(u8, @intCast(abs)), @sizeOf(InputAbsInfo));
}

const BUS_VIRTUAL: u16 = 0x06;

// Physical touchpad geometry (Framework 16, matches libinput's 124x77mm).
// Only used as metadata for the virtual device's absinfo resolution.
const TOUCHPAD_W_MM: f64 = 124.0;
const TOUCHPAD_H_MM: f64 = 77.0;

const MAX_SLOTS: usize = 16;

// ---------------------------------------------------------------------------
// logging
// ---------------------------------------------------------------------------

var g_debug: bool = false;
var g_stop: std.atomic.Value(bool) = std.atomic.Value(bool).init(false);

fn info(comptime fmt: []const u8, args: anytype) void {
    std.debug.print(fmt ++ "\n", args);
}

fn dbg(comptime fmt: []const u8, args: anytype) void {
    if (g_debug) std.debug.print("[debug] " ++ fmt ++ "\n", args);
}

fn errno() c_int {
    return __errno_location().*;
}

fn nowMs() i64 {
    var tv = TimeVal{ .sec = 0, .usec = 0 };
    _ = gettimeofday(&tv, null);
    return tv.sec * 1000 + @divTrunc(tv.usec, 1000);
}

fn sleepMs(ms: i64) void {
    var ts = TimeSpec{ .sec = @divTrunc(ms, 1000), .nsec = @intCast(@mod(ms, 1000) * 1_000_000) };
    while (nanosleep(&ts, &ts) != 0 and errno() == EINTR) {}
}

// ---------------------------------------------------------------------------
// config
// ---------------------------------------------------------------------------

const Config = struct {
    device: [:0]const u8 = "PIXA3854:00 093A:0274 Touchpad",
    watch: ?[:0]const u8 = null,
    x_min: ?i32 = null,
    x_max: ?i32 = null,
    y_min: ?i32 = null,
    y_max: ?i32 = null,
    out_x: i32 = 32767,
    out_y: i32 = 32767,
    aspect: ?f64 = null,
    click_on_touch: bool = true,
    screen_w: ?i32 = null,
    screen_h: ?i32 = null,
    sx_min: ?i32 = null,
    sx_max: ?i32 = null,
    sy_min: ?i32 = null,
    sy_max: ?i32 = null,
    focus_match: ?[:0]const u8 = null,
    focus_query: ?[:0]const u8 = null,
};

const usage_text =
    \\osu-touchpad — map a touchpad (evdev, multitouch Type B) to an absolute
    \\uinput pointer, grabbed exclusively while active.
    \\
    \\usage: osu-touchpad [options]
    \\
    \\  --device PATH|NAME     physical device: absolute path, or exact evdev
    \\                         name to scan /dev/input/event* for
    \\                         (default: "PIXA3854:00 093A:0274 Touchpad")
    \\  --watch SUBSTR         only active while some /proc/*/cmdline contains
    \\                         SUBSTR (skip own pid); without this flag the
    \\                         mapper is active from startup
    \\  --x-min N --x-max N    physical crop (default: device absinfo = full)
    \\  --y-min N --y-max N
    \\  --aspect W:H           center-crop the active area to this ratio
    \\  --screen-width N       logical output size the screen sub-box is
    \\  --screen-height N      expressed in (niri logical px; panel: 2048x1280)
    \\  --screen-x-min N       screen sub-box the pad area maps onto,
    \\  --screen-x-max N       logical pixels (default: whole output)
    \\  --screen-y-min N
    \\  --screen-y-max N
    \\  --focus-match SUBSTR   engage only while the focused-window query
    \\                         output contains SUBSTR; falls back to --watch
    \\                         when the query command fails
    \\  --focus-query CMD      shell command returning focused-window info
    \\                         (default: "niri msg focused-window")
    \\  --output-width N       virtual ABS_X max, range 0..N (default 32767)
    \\  --output-height N      virtual ABS_Y max, range 0..N (default 32767)
    \\  --no-click-on-touch    do not emit BTN_LEFT on finger contact
    \\  --debug                verbose finger/raw/mapped logging
    \\  --help                 this text
    \\
;

fn parseIntArg(comptime T: type, v: [:0]const u8) !T {
    return std.fmt.parseInt(T, v, 10) catch error.BadArgs;
}

fn parseAspect(v: [:0]const u8) !f64 {
    var split: ?usize = null;
    for (v, 0..) |ch, i| {
        if (ch == ':') {
            split = i;
            break;
        }
    }
    const sep = split orelse return error.BadArgs;
    const w = std.fmt.parseFloat(f64, v[0..sep]) catch return error.BadArgs;
    const h = std.fmt.parseFloat(f64, v[sep + 1 ..]) catch return error.BadArgs;
    if (!(w > 0) or !(h > 0)) return error.BadArgs;
    return w / h;
}

fn parseArgs(argv: [][:0]const u8) !Config {
    var cfg = Config{};
    var i: usize = 1; // skip argv[0]
    while (i < argv.len) : (i += 1) {
        const a = argv[i];
        if (std.mem.eql(u8, a, "--help")) {
            info("{s}", .{usage_text});
            return error.HelpShown;
        } else if (std.mem.eql(u8, a, "--debug")) {
            g_debug = true;
        } else if (std.mem.eql(u8, a, "--no-click-on-touch")) {
            cfg.click_on_touch = false;
        } else if (std.mem.eql(u8, a, "--device") or
            std.mem.eql(u8, a, "--watch") or
            std.mem.eql(u8, a, "--x-min") or
            std.mem.eql(u8, a, "--x-max") or
            std.mem.eql(u8, a, "--y-min") or
            std.mem.eql(u8, a, "--y-max") or
            std.mem.eql(u8, a, "--aspect") or
            std.mem.eql(u8, a, "--output-width") or
            std.mem.eql(u8, a, "--output-height") or
            std.mem.eql(u8, a, "--screen-width") or
            std.mem.eql(u8, a, "--screen-height") or
            std.mem.eql(u8, a, "--screen-x-min") or
            std.mem.eql(u8, a, "--screen-x-max") or
            std.mem.eql(u8, a, "--screen-y-min") or
            std.mem.eql(u8, a, "--screen-y-max") or
            std.mem.eql(u8, a, "--focus-match") or
            std.mem.eql(u8, a, "--focus-query"))
        {
            i += 1;
            if (i >= argv.len) {
                info("missing value for {s}", .{a});
                return error.BadArgs;
            }
            const v = argv[i];
            if (std.mem.eql(u8, a, "--device")) {
                cfg.device = v;
            } else if (std.mem.eql(u8, a, "--watch")) {
                cfg.watch = v;
            } else if (std.mem.eql(u8, a, "--x-min")) {
                cfg.x_min = try parseIntArg(i32, v);
            } else if (std.mem.eql(u8, a, "--x-max")) {
                cfg.x_max = try parseIntArg(i32, v);
            } else if (std.mem.eql(u8, a, "--y-min")) {
                cfg.y_min = try parseIntArg(i32, v);
            } else if (std.mem.eql(u8, a, "--y-max")) {
                cfg.y_max = try parseIntArg(i32, v);
            } else if (std.mem.eql(u8, a, "--aspect")) {
                cfg.aspect = try parseAspect(v);
            } else if (std.mem.eql(u8, a, "--output-width")) {
                cfg.out_x = try parseIntArg(i32, v);
            } else if (std.mem.eql(u8, a, "--output-height")) {
                cfg.out_y = try parseIntArg(i32, v);
            } else if (std.mem.eql(u8, a, "--screen-width")) {
                cfg.screen_w = try parseIntArg(i32, v);
            } else if (std.mem.eql(u8, a, "--screen-height")) {
                cfg.screen_h = try parseIntArg(i32, v);
            } else if (std.mem.eql(u8, a, "--screen-x-min")) {
                cfg.sx_min = try parseIntArg(i32, v);
            } else if (std.mem.eql(u8, a, "--screen-x-max")) {
                cfg.sx_max = try parseIntArg(i32, v);
            } else if (std.mem.eql(u8, a, "--screen-y-min")) {
                cfg.sy_min = try parseIntArg(i32, v);
            } else if (std.mem.eql(u8, a, "--screen-y-max")) {
                cfg.sy_max = try parseIntArg(i32, v);
            } else if (std.mem.eql(u8, a, "--focus-match")) {
                cfg.focus_match = v;
            } else if (std.mem.eql(u8, a, "--focus-query")) {
                cfg.focus_query = v;
            }
        } else {
            info("unknown argument: {s}", .{a});
            return error.BadArgs;
        }
    }
    if (cfg.out_x <= 0 or cfg.out_y <= 0) {
        info("output range must be positive", .{});
        return error.BadArgs;
    }
    if ((cfg.screen_w == null) != (cfg.screen_h == null)) {
        info("--screen-width and --screen-height go together", .{});
        return error.BadArgs;
    }
    if (cfg.screen_w) |w| {
        if (w <= 0 or cfg.screen_h.? <= 0) {
            info("screen size must be positive", .{});
            return error.BadArgs;
        }
    }
    const screen_box = cfg.sx_min != null or cfg.sx_max != null or cfg.sy_min != null or cfg.sy_max != null;
    if (screen_box and cfg.screen_w == null) {
        info("screen sub-box requires --screen-width and --screen-height", .{});
        return error.BadArgs;
    }
    return cfg;
}

// ---------------------------------------------------------------------------
// small helpers (own implementations to stay zig-version-proof)
// ---------------------------------------------------------------------------

fn indexOfSub(hay: []const u8, needle: []const u8) ?usize {
    if (needle.len == 0) return 0;
    if (needle.len > hay.len) return null;
    var i: usize = 0;
    while (i <= hay.len - needle.len) : (i += 1) {
        if (std.mem.eql(u8, hay[i..][0..needle.len], needle)) return i;
    }
    return null;
}

fn allDigits(s: []const u8) bool {
    if (s.len == 0) return false;
    for (s) |c| {
        if (c < '0' or c > '9') return false;
    }
    return true;
}

fn atoiSmall(s: []const u8) ?c_int {
    var v: c_int = 0;
    for (s) |c| {
        v = v * 10 + (c - '0');
        if (v > 1 << 22) return v;
    }
    return v;
}

// ---------------------------------------------------------------------------
// watch mode: is the target process alive?
// ---------------------------------------------------------------------------

fn watchMatches(pattern: []const u8) bool {
    const d = opendir("/proc") orelse return false;
    defer _ = closedir(d);
    const self_pid = getpid();
    while (true) {
        const ent = readdir(d) orelse break;
        var nl: usize = 0;
        while (nl < ent.d_name.len and ent.d_name[nl] != 0) : (nl += 1) {}
        const name = ent.d_name[0..nl];
        if (!allDigits(name)) continue;
        const pid = atoiSmall(name) orelse continue;
        // skip ourselves: our own cmdline contains the watch pattern
        if (pid == self_pid) continue;

        var pbuf: [64]u8 = undefined;
        const ppath = std.fmt.bufPrintZ(&pbuf, "/proc/{d}/cmdline", .{pid}) catch continue;
        const fd = open(ppath.ptr, O_RDONLY);
        if (fd < 0) continue;
        var cbuf: [4096]u8 = undefined;
        const n = read(fd, &cbuf, cbuf.len);
        _ = close(fd);
        if (n <= 0) continue;
        if (indexOfSub(cbuf[0..@intCast(n)], pattern) != null) return true;
    }
    return false;
}

// ---------------------------------------------------------------------------
// focus mode: query the compositor for the focused window
// ---------------------------------------------------------------------------

/// Run `cmd` via sh -c and return its stdout, or null when the command
/// fails (missing binary, ipc error, ...). The returned slice aliases the
/// caller-provided buffer and is used immediately.
fn focusedWindowText(cmd: [:0]const u8, out: []u8) ?[]const u8 {
    @memset(out, 0);
    const p = popen(cmd.ptr, "r") orelse return null;
    const n = fread(out.ptr, 1, out.len - 1, p);
    const st = pclose(p);
    if (st != 0) return null;
    return out[0..n];
}

// ---------------------------------------------------------------------------
// the mapper
// ---------------------------------------------------------------------------

const Crop = struct { x0: i32, x1: i32, y0: i32, y1: i32 };

const Slot = struct {
    active: bool = false,
    tracking_id: i32 = -1,
};

const Mapper = struct {
    cfg: Config,
    phys_fd: c_int = -1,
    ui_fd: c_int = -1,
    active: bool = false,
    phys_name: [256]u8 = undefined,
    phys_name_len: usize = 0,

    crop: Crop = .{ .x0 = 0, .x1 = 1, .y0 = 0, .y1 = 1 },
    // output-space box: the device crop is stretched onto 0..ox1 / 0..oy1
    // offsets, so a screen sub-box can be targeted
    ox0: f64 = 0,
    ox1: f64 = 1,
    oy0: f64 = 0,
    oy1: f64 = 1,
    slot_cur: usize = 0,
    slots: [MAX_SLOTS]Slot = [_]Slot{Slot{}} ** MAX_SLOTS,
    primary: ?usize = null,
    primary_have_pos: bool = false,
    want_press: bool = false,
    raw_x: i32 = 0,
    raw_y: i32 = 0,
    phys_down: bool = false,
    ours_down: bool = false,
    out_sent_btn: bool = false,
    pending_pos: bool = false,

    out: [256]InputEvent = undefined,
    out_n: usize = 0,

    // ---- device discovery -------------------------------------------------

    fn lookupPhysical(self: *Mapper) c_int {
        if (self.cfg.device.len > 0 and self.cfg.device[0] == '/') {
            const fd = open(self.cfg.device.ptr, O_RDONLY | O_NONBLOCK);
            if (fd < 0) {
                info("cannot open {s}: errno={d}", .{ self.cfg.device, errno() });
                return -1;
            }
            self.rememberName(fd);
            return fd;
        }
        var i: c_int = 0;
        while (i < 256) : (i += 1) {
            var pbuf: [32]u8 = undefined;
            const path = std.fmt.bufPrintZ(&pbuf, "/dev/input/event{d}", .{i}) catch continue;
            const fd = open(path.ptr, O_RDONLY | O_NONBLOCK);
            if (fd < 0) continue;
            var namebuf: [256]u8 = undefined;
            @memset(namebuf[0..], 0);
            const ret = ioctl(fd, eviocgname(namebuf.len), &namebuf);
            if (ret > 0) {
                var nl: usize = 0;
                while (nl < namebuf.len and namebuf[nl] != 0) : (nl += 1) {}
                if (std.mem.eql(u8, namebuf[0..nl], self.cfg.device)) {
                    self.phys_name = namebuf;
                    self.phys_name_len = nl;
                    return fd;
                }
            }
            _ = close(fd);
        }
        info("device not found: {s}", .{self.cfg.device});
        return -1;
    }

    fn rememberName(self: *Mapper, fd: c_int) void {
        @memset(self.phys_name[0..], 0);
        self.phys_name_len = 0;
        const ret = ioctl(fd, eviocgname(self.phys_name.len), &self.phys_name);
        if (ret > 0) {
            while (self.phys_name_len < self.phys_name.len and self.phys_name[self.phys_name_len] != 0) : (self.phys_name_len += 1) {}
        }
    }

    fn absInfo(fd: c_int, code: i16) ?InputAbsInfo {
        var info_: InputAbsInfo = undefined;
        if (ioctl(fd, eviocgabs(code), &info_) < 0) return null;
        return info_;
    }

    fn computeCrop(self: *Mapper, fd: c_int) ?Crop {
        const ax = absInfo(fd, ABS_X) orelse {
            info("EVIOCGABS(ABS_X) failed: errno={d}", .{errno()});
            return null;
        };
        const ay = absInfo(fd, ABS_Y) orelse {
            info("EVIOCGABS(ABS_Y) failed: errno={d}", .{errno()});
            return null;
        };
        var c = Crop{
            .x0 = self.cfg.x_min orelse ax.minimum,
            .x1 = self.cfg.x_max orelse ax.maximum,
            .y0 = self.cfg.y_min orelse ay.minimum,
            .y1 = self.cfg.y_max orelse ay.maximum,
        };
        if (self.cfg.aspect) |r| {
            const w: f64 = @floatFromInt(c.x1 - c.x0);
            const h: f64 = @floatFromInt(c.y1 - c.y0);
            if (w <= 0 or h <= 0) return null;
            if (w / h > r) {
                const nw = h * r;
                const pad: i32 = @intFromFloat(@max(0.0, (w - nw) / 2.0));
                c.x0 += pad;
                c.x1 -= pad;
            } else {
                const nh = w / r;
                const pad: i32 = @intFromFloat(@max(0.0, (h - nh) / 2.0));
                c.y0 += pad;
                c.y1 -= pad;
            }
        }
        if (c.x1 <= c.x0 or c.y1 <= c.y0) {
            info("invalid active area ({d}..{d} x {d}..{d})", .{ c.x0, c.x1, c.y0, c.y1 });
            return null;
        }
        return c;
    }

    /// Translate the configured screen sub-box (logical pixels) into
    /// output-space coordinates once per activation.
    fn computeOutBox(self: *Mapper) void {
        const out_xf: f64 = @floatFromInt(self.cfg.out_x);
        const out_yf: f64 = @floatFromInt(self.cfg.out_y);
        if (self.cfg.screen_w) |w| {
            const wf: f64 = @floatFromInt(w);
            const hf: f64 = @floatFromInt(self.cfg.screen_h.?);
            const x0: f64 = @floatFromInt(self.cfg.sx_min orelse 0);
            const x1: f64 = @floatFromInt(self.cfg.sx_max orelse w);
            const y0: f64 = @floatFromInt(self.cfg.sy_min orelse 0);
            const y1: f64 = @floatFromInt(self.cfg.sy_max orelse self.cfg.screen_h.?);
            self.ox0 = x0 / wf * out_xf;
            self.ox1 = x1 / wf * out_xf;
            self.oy0 = y0 / hf * out_yf;
            self.oy1 = y1 / hf * out_yf;
        } else {
            self.ox0 = 0;
            self.ox1 = out_xf;
            self.oy0 = 0;
            self.oy1 = out_yf;
        }
    }

    // ---- lifecycle --------------------------------------------------------

    fn activate(self: *Mapper) bool {
        const fd = self.lookupPhysical();
        if (fd < 0) return false;
        self.phys_fd = fd;

        const crop = self.computeCrop(fd) orelse {
            _ = close(fd);
            self.phys_fd = -1;
            return false;
        };

        if (ioctl(fd, EVIOCGRAB, @as(c_int, 1)) < 0) {
            info("EVIOCGRAB failed: errno={d}", .{errno()});
            _ = close(fd);
            self.phys_fd = -1;
            return false;
        }
        self.crop = crop;
        self.computeOutBox();

        const ui = self.createUinput();
        if (ui < 0) {
            _ = ioctl(fd, EVIOCGRAB, @as(c_int, 0));
            _ = close(fd);
            self.phys_fd = -1;
            return false;
        }
        self.ui_fd = ui;

        // reset per-session MT state; contacts already in progress are
        // deliberately ignored (we only ever see their updates, never a
        // fresh tracking-id down), so no surprise click on activation
        self.slot_cur = 0;
        self.slots = [_]Slot{Slot{}} ** MAX_SLOTS;
        self.primary = null;
        self.primary_have_pos = false;
        self.want_press = false;
        self.phys_down = false;
        self.ours_down = false;
        self.out_sent_btn = false;
        self.pending_pos = false;
        self.out_n = 0;
        self.active = true;

        info("tablet mode ON: grabbed \"{s}\" crop=[{d}..{d} x {d}..{d}] box=[{d}..{d} x {d}..{d}] out=0..{d}x0..{d}", .{
            self.phys_name[0..self.phys_name_len],
            crop.x0,
            crop.x1,
            crop.y0,
            crop.y1,
            self.ox0,
            self.ox1,
            self.oy0,
            self.oy1,
            self.cfg.out_x,
            self.cfg.out_y,
        });
        return true;
    }

    fn deactivate(self: *Mapper) void {
        if (!self.active) return;
        // make sure no button stays logically pressed before the device dies
        if (self.ui_fd >= 0) {
            if (self.out_sent_btn) {
                self.out_sent_btn = false;
                self.emitKey(BTN_LEFT, 0);
                self.pushSyn();
                self.writeOut();
            } else if (self.out_n > 0) {
                self.writeOut();
            }
            _ = ioctl(self.ui_fd, UI_DEV_DESTROY, @as(c_int, 0));
            _ = close(self.ui_fd);
            self.ui_fd = -1;
        }
        if (self.phys_fd >= 0) {
            if (ioctl(self.phys_fd, EVIOCGRAB, @as(c_int, 0)) < 0) {
                const e = errno();
                if (e == ENODEV) {
                    dbg("grab release: device already gone", .{});
                } else {
                    info("EVIOCGRAB release failed: errno={d}", .{e});
                }
            }
            _ = close(self.phys_fd);
            self.phys_fd = -1;
        }
        self.active = false;
        info("tablet mode OFF: ungrabbed, virtual device removed", .{});
    }

    // ---- uinput -----------------------------------------------------------

    fn createUinput(self: *Mapper) c_int {
        const fd = open("/dev/uinput", O_WRONLY | O_NONBLOCK);
        if (fd < 0) {
            info("cannot open /dev/uinput: errno={d}", .{errno()});
            return -1;
        }
        var ok = true;
        ok = ok and ioctl(fd, UI_SET_EVBIT, @as(c_int, EV_KEY)) >= 0;
        ok = ok and ioctl(fd, UI_SET_KEYBIT, @as(c_int, BTN_LEFT)) >= 0;
        ok = ok and ioctl(fd, UI_SET_EVBIT, @as(c_int, EV_ABS)) >= 0;
        ok = ok and ioctl(fd, UI_SET_ABSBIT, @as(c_int, ABS_X)) >= 0;
        ok = ok and ioctl(fd, UI_SET_ABSBIT, @as(c_int, ABS_Y)) >= 0;

        const res_x: i32 = @intFromFloat(@round(@as(f64, @floatFromInt(self.cfg.out_x)) / TOUCHPAD_W_MM));
        const res_y: i32 = @intFromFloat(@round(@as(f64, @floatFromInt(self.cfg.out_y)) / TOUCHPAD_H_MM));

        var absx = UinputAbsSetup{
            .code = @bitCast(ABS_X),
            .absinfo = .{ .value = 0, .minimum = 0, .maximum = self.cfg.out_x, .fuzz = 0, .flat = 0, .resolution = @max(1, res_x) },
        };
        var absy = UinputAbsSetup{
            .code = @bitCast(ABS_Y),
            .absinfo = .{ .value = 0, .minimum = 0, .maximum = self.cfg.out_y, .fuzz = 0, .flat = 0, .resolution = @max(1, res_y) },
        };
        ok = ok and ioctl(fd, UI_ABS_SETUP, &absx) >= 0;
        ok = ok and ioctl(fd, UI_ABS_SETUP, &absy) >= 0;

        var setup = std.mem.zeroes(UinputSetup);
        setup.id = .{ .bustype = BUS_VIRTUAL, .vendor = 0x1209, .product = 0x00f7, .version = 1 };
        const name = "Framework 16 osu! Touchpad Tablet";
        @memcpy(setup.name[0..name.len], name);

        ok = ok and ioctl(fd, UI_DEV_SETUP, &setup) >= 0;
        if (!ok) {
            info("uinput setup failed: errno={d}", .{errno()});
            _ = close(fd);
            return -1;
        }
        if (ioctl(fd, UI_DEV_CREATE, @as(c_int, 0)) < 0) {
            info("UI_DEV_CREATE failed: errno={d}", .{errno()});
            _ = close(fd);
            return -1;
        }
        return fd;
    }

    // ---- output side ------------------------------------------------------

    fn nowTv() TimeVal {
        var tv = TimeVal{ .sec = 0, .usec = 0 };
        _ = gettimeofday(&tv, null);
        return tv;
    }

    fn pushEvent(self: *Mapper, typ: u16, code: i16, value: i32) void {
        if (self.out_n >= self.out.len) self.writeOut();
        const tv = nowTv();
        self.out[self.out_n] = .{
            .sec = @intCast(@max(0, tv.sec)),
            .usec = @intCast(@max(0, tv.usec)),
            .type = typ,
            .code = code,
            .value = value,
        };
        self.out_n += 1;
    }

    fn writeOut(self: *Mapper) void {
        if (self.out_n == 0 or self.ui_fd < 0) {
            self.out_n = 0;
            return;
        }
        const bytes = std.mem.sliceAsBytes(self.out[0..self.out_n]);
        var off: usize = 0;
        while (off < bytes.len) {
            const n = write(self.ui_fd, bytes.ptr + off, bytes.len - off);
            if (n <= 0) {
                info("uinput write failed: errno={d}", .{errno()});
                break;
            }
            off += @intCast(n);
        }
        self.out_n = 0;
    }

    fn pushSyn(self: *Mapper) void {
        self.pushEvent(EV_SYN, SYN_REPORT, 0);
    }

    fn emitKey(self: *Mapper, code: i16, value: i32) void {
        self.pushEvent(EV_KEY, code, value);
    }

    fn syncBtn(self: *Mapper) void {
        const want = self.phys_down or self.ours_down;
        if (want == self.out_sent_btn) return;
        self.out_sent_btn = want;
        self.emitKey(BTN_LEFT, if (want) @as(i32, 1) else 0);
        dbg("btn: {s}", .{if (want) "down" else "up"});
    }

    // ---- input side -------------------------------------------------------

    fn mapCoord(v: i32, lo: i32, hi: i32, b0: f64, b1: f64, out_max: i32) i32 {
        if (hi <= lo) return 0;
        const vv = std.math.clamp(v, lo, hi);
        const n = @as(f64, @floatFromInt(vv - lo)) / @as(f64, @floatFromInt(hi - lo));
        const scaled = b0 + n * (b1 - b0) + 0.5;
        const iv: i64 = @intFromFloat(scaled);
        return @intCast(@min(@max(iv, 0), out_max));
    }

    fn onTracking(self: *Mapper, tid: i32) void {
        const s = self.slot_cur;
        if (tid >= 0) {
            self.slots[s] = .{ .active = true, .tracking_id = tid };
            if (self.primary == null) {
                self.primary = s;
                self.primary_have_pos = false;
                self.want_press = self.cfg.click_on_touch;
                dbg("finger down: slot={d} tracking_id={d}", .{ s, tid });
            } else {
                dbg("secondary finger ignored: slot={d} tracking_id={d}", .{ s, tid });
            }
        } else {
            if (!self.slots[s].active) return; // contact we never saw
            dbg("finger up: slot={d}", .{s});
            self.slots[s] = .{};
            if (self.primary == s) {
                self.primary = null;
                self.primary_have_pos = false;
                self.want_press = false;
                if (self.ours_down) {
                    self.ours_down = false;
                    self.syncBtn();
                }
            }
        }
    }

    fn onPosition(self: *Mapper, axis_x: bool, val: i32) void {
        // only the primary contact may move the cursor; secondary fingers and
        // contacts that were already down before activation are ignored
        const p = self.primary orelse return;
        if (self.slot_cur != p) return;
        if (axis_x) self.raw_x = val else self.raw_y = val;
        self.primary_have_pos = true;
        self.pending_pos = true;
    }

    fn dispatch(self: *Mapper, ev: InputEvent) void {
        switch (ev.type) {
            EV_ABS => switch (ev.code) {
                ABS_MT_SLOT => {
                    if (ev.value >= 0 and ev.value < MAX_SLOTS) self.slot_cur = @intCast(ev.value);
                },
                ABS_MT_TRACKING_ID => self.onTracking(ev.value),
                ABS_MT_POSITION_X => self.onPosition(true, ev.value),
                ABS_MT_POSITION_Y => self.onPosition(false, ev.value),
                else => {},
            },
            EV_KEY => {
                if (ev.code == BTN_LEFT) {
                    self.phys_down = ev.value != 0;
                    self.syncBtn();
                }
                // BTN_TOUCH / BTN_TOOL_* are irrelevant for the virtual device
            },
            EV_SYN => {
                if (ev.code == SYN_REPORT) self.flushFrame();
            },
            else => {},
        }
    }

    fn flushFrame(self: *Mapper) void {
        // position first, then the synthesized press, then SYN: the click
        // always lands on the frame's fresh coordinates
        if (self.pending_pos) {
            self.pending_pos = false;
            const mx = mapCoord(self.raw_x, self.crop.x0, self.crop.x1, self.ox0, self.ox1, self.cfg.out_x);
            const my = mapCoord(self.raw_y, self.crop.y0, self.crop.y1, self.oy0, self.oy1, self.cfg.out_y);
            self.pushEvent(EV_ABS, ABS_X, mx);
            self.pushEvent(EV_ABS, ABS_Y, my);
            dbg("raw: x={d} y={d}", .{ self.raw_x, self.raw_y });
            dbg("mapped: x={d} y={d}", .{ mx, my });
        }
        if (self.want_press and self.primary != null and self.primary_have_pos) {
            self.want_press = false;
            self.ours_down = true;
            self.syncBtn();
        }
        if (self.out_n > 0) {
            if (self.out_n >= self.out.len) self.writeOut();
            self.pushSyn();
            self.writeOut();
        }
    }

    fn drainPhys(self: *Mapper) void {
        var buf: [64 * @sizeOf(InputEvent)]u8 align(@alignOf(InputEvent)) = undefined;
        while (true) {
            const n = read(self.phys_fd, &buf, buf.len);
            if (n < 0) {
                const e = errno();
                if (e == EAGAIN) break;
                if (e == EINTR) continue;
                // device went away (unplugged / renumbered / suspended)
                info("physical device read error: errno={d}", .{e});
                self.deactivate();
                break;
            }
            if (n == 0) {
                info("physical device EOF", .{});
                self.deactivate();
                break;
            }
            const count: usize = @intCast(@divTrunc(n, @sizeOf(InputEvent)));
            const events = @as([*]const InputEvent, @ptrCast(@alignCast(&buf)))[0..count];
            for (events) |ev| self.dispatch(ev);
            if (@rem(n, @sizeOf(InputEvent)) != 0) {
                dbg("partial event read ({d} bytes), dropping tail", .{n});
                break;
            }
        }
    }
};

// ---------------------------------------------------------------------------
// entry point
// ---------------------------------------------------------------------------

fn termHandler(sig: c_int) callconv(.c) void {
    _ = sig;
    g_stop.store(true, .seq_cst);
}

pub fn main(init: std.process.Init.Minimal) !void {
    const vector = init.args.vector;
    var arg_storage: [128][:0]const u8 = undefined;
    var argc: usize = 0;
    for (vector) |raw| {
        if (argc >= arg_storage.len) break;
        arg_storage[argc] = std.mem.span(raw);
        argc += 1;
    }
    const argv = arg_storage[0..argc];

    const cfg = parseArgs(argv) catch |err| {
        if (err == error.HelpShown) return;
        info("{s}", .{usage_text});
        return err;
    };

    _ = signal(SIGINT_, termHandler);
    _ = signal(SIGTERM_, termHandler);

    var m = Mapper{ .cfg = cfg };
    defer m.deactivate();

    var last_scan: i64 = 0;
    var last_try: i64 = 0;
    var scan_cache: bool = true;
    var fbuf: [8192]u8 = undefined;

    while (!g_stop.load(.seq_cst)) {
        const now = nowMs();

        // ---- decide whether tablet mode should be engaged ----
        const wanted = blk: {
            if (cfg.focus_match) |fm| {
                if (now - last_scan >= 500) {
                    last_scan = now;
                    const q = cfg.focus_query orelse "niri msg focused-window";
                    scan_cache = blk2: {
                        if (focusedWindowText(q, fbuf[0..])) |txt|
                            break :blk2 indexOfSub(txt, fm) != null;
                        // compositor query unavailable: fall back to process watch
                        if (cfg.watch) |p| break :blk2 watchMatches(p);
                        break :blk2 true;
                    };
                }
                break :blk scan_cache;
            }
            if (cfg.watch) |p| {
                if (now - last_scan >= 500) {
                    last_scan = now;
                    scan_cache = watchMatches(p);
                }
                break :blk scan_cache;
            }
            break :blk true;
        };

        if (wanted and !m.active and now - last_try >= 2000) {
            if (!m.activate()) last_try = nowMs();
        } else if (!wanted and m.active) {
            m.deactivate();
        }

        if (m.active) {
            var pfd = PollFd{ .fd = m.phys_fd, .events = POLLIN, .revents = 0 };
            const r = poll(&pfd, 1, 250);
            if (r < 0) {
                if (errno() == EINTR) continue;
                sleepMs(250);
            } else if (r > 0) {
                if ((pfd.revents & (POLLERR_ | POLLHUP_ | POLLNVAL_)) != 0) {
                    info("physical device vanished (revents={d})", .{pfd.revents});
                    m.deactivate();
                } else if ((pfd.revents & POLLIN) != 0) {
                    m.drainPhys();
                }
            }
        } else {
            sleepMs(250);
        }
    }

    m.deactivate();
}
