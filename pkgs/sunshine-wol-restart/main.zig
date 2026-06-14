const std = @import("std");

const RestartError = error{RestartFailed};

fn usage() noreturn {
    std.debug.print("usage: sunshine-wol-restart <target-mac> <listen-ip> <port> <user> <service>...\n", .{});
    std.process.exit(2);
}

fn parseMac(text: []const u8) ![6]u8 {
    var mac: [6]u8 = undefined;
    var parts = std.mem.splitScalar(u8, text, ':');

    for (&mac) |*byte| {
        const part = parts.next() orelse return error.InvalidMac;
        if (part.len == 0 or part.len > 2) return error.InvalidMac;
        byte.* = try std.fmt.parseInt(u8, part, 16);
    }

    if (parts.next() != null) return error.InvalidMac;
    return mac;
}

fn isWolPacket(buf: []const u8, mac: *const [6]u8) bool {
    if (buf.len < 102) return false;

    for (buf[0..6]) |byte| {
        if (byte != 0xff) return false;
    }

    for (0..16) |repeat| {
        const start = 6 + repeat * 6;
        if (!std.mem.eql(u8, buf[start .. start + 6], mac)) return false;
    }

    return true;
}

test "detects magic packet" {
    const mac = try parseMac("04:7c:16:80:3c:2c");
    var packet: [102]u8 = undefined;
    @memset(packet[0..6], 0xff);
    for (0..16) |repeat| {
        const start = 6 + repeat * 6;
        @memcpy(packet[start .. start + 6], &mac);
    }

    try std.testing.expect(isWolPacket(&packet, &mac));
    packet[101] ^= 1;
    try std.testing.expect(!isWolPacket(&packet, &mac));
}

fn restartServices(allocator: std.mem.Allocator, io: std.Io, user: []const u8, services: []const [:0]const u8) !void {
    var argv = try allocator.alloc([]const u8, 4 + services.len);
    defer allocator.free(argv);

    const machine = try std.fmt.allocPrint(allocator, "--machine={s}@.host", .{user});
    defer allocator.free(machine);

    argv[0] = "systemctl";
    argv[1] = machine;
    argv[2] = "--user";
    argv[3] = "restart";
    for (services, argv[4..]) |service, *arg| arg.* = service;

    var child = try std.process.spawn(io, .{ .argv = argv });
    const term = try child.wait(io);
    switch (term) {
        .exited => |code| if (code != 0) return RestartError.RestartFailed,
        else => return RestartError.RestartFailed,
    }
}

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len < 6) usage();

    const mac = parseMac(args[1]) catch |err| {
        std.debug.print("invalid MAC '{s}': {}\n", .{ args[1], err });
        usage();
    };
    const port = std.fmt.parseInt(u16, args[3], 10) catch |err| {
        std.debug.print("invalid port '{s}': {}\n", .{ args[3], err });
        usage();
    };
    const user = args[4];
    const services = args[5..];

    const addr = try std.Io.net.IpAddress.parseIp4(args[2], port);
    const sock = try addr.bind(init.io, .{ .mode = .dgram, .protocol = .udp });
    defer sock.close(init.io);

    var buf: [1500]u8 = undefined;
    std.debug.print("listening for WoL packets on {s}:{}\n", .{ args[2], port });

    while (true) {
        const msg = try sock.receive(init.io, &buf);
        if (!isWolPacket(msg.data, &mac)) continue;

        std.debug.print("WoL detected; restarting services\n", .{});
        restartServices(allocator, init.io, user, services) catch |err| {
            std.debug.print("restart failed: {}\n", .{err});
        };
    }
}
