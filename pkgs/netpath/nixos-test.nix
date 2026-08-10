{ netpath }:
{
  name = "netpath";
  nodes = {
    # Gateway on the lab LAN: static IP, fixed MAC, honors gratuitous ARP
    router =
      { ... }:
      {
        virtualisation.vlans = [ 1 ];
        networking.firewall.enable = false;
        networking.useNetworkd = true;
        systemd.network.links."10-router" = {
          matchConfig.OriginalName = "eth1";
          linkConfig.MACAddress = "00:11:22:33:44:55";
        };
        systemd.network.networks."10-lan" = {
          matchConfig.Name = "eth1";
          networkConfig.Address = "10.0.0.1/24";
        };
        boot.kernel.sysctl."net.ipv4.conf.all.arp_accept" = 1;
      };

    # Triple-NIC host: eth1 (ethernet) + eth2/eth3 (two wifi cards) on the
    # same broadcast domain, management addresses from `systemd-networkd`
    machine =
      { ... }:
      {
        virtualisation.vlans = [ 1 1 1 ];
        networking.firewall.enable = false;
        networking.useNetworkd = true;
        systemd.network.networks."10-eth1" = {
          matchConfig.Name = "eth1";
          networkConfig.Address = "10.0.0.10/24";
        };
        systemd.network.networks."11-eth2" = {
          matchConfig.Name = "eth2";
          networkConfig.Address = "10.0.0.20/24";
        };
        systemd.network.networks."12-eth3" = {
          matchConfig.Name = "eth3";
          networkConfig.Address = "10.0.0.30/24";
        };

        environment.systemPackages = [ netpath ];
        environment.etc."netpath.json".text = builtins.toJSON {
          routing = {
            table = 100;
            priority = 10000;
            probe = "10.0.0.1";
          };
          profiles = [
            {
              name = "lab";
              cidr = "10.0.0.0/24";
              gateway = "10.0.0.1";
              gateway_mac = "00:11:22:33:44:55";
              vip = "10.0.0.50";
              paths = {
                ethernet = [ "eth1" ];
                wifi = [ "eth2" "eth3" ];
              };
            }
          ];
        };

        # Mirror of the `services.netpath` module units
        systemd.services.netpath-init = {
          description = "Select the initial trusted-LAN path";
          wantedBy = [ "multi-user.target" ];
          wants = [ "network-online.target" ];
          after = [ "network-online.target" ];
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${netpath}/bin/netpath auto";
            Restart = "on-failure";
            RestartSec = "5s";
          };
        };
        systemd.services.netpath-reconcile = {
          description = "Reconcile the active trusted-LAN path";
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${netpath}/bin/netpath reconcile";
          };
        };
        systemd.timers.netpath-reconcile = {
          description = "Periodically reconcile the active trusted-LAN path";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnBootSec = "5s";
            OnUnitActiveSec = "3s";
            Unit = "netpath-reconcile.service";
          };
        };
      };
  };

  testScript = ''
    import json

    start_all()

    for dev in ["eth1", "eth2", "eth3"]:
        machine.wait_until_succeeds(f"ip link show {dev} | grep -q 'state UP'", timeout=120)

    # NOTE: avoid `grep -q` on netpath pipes: nushell turns the EPIPE it
    #       causes into a nonzero exit.
    machine.wait_until_succeeds("netpath check | grep 'ok: lab ethernet'", timeout=120)

    # status reports every device ready, per the new per-device shape
    st = json.loads(machine.succeed("netpath status --json"))
    rows = [(p["role"], p["device"], p["ready"]) for p in st["profiles"][0]["paths"]]
    assert ("ethernet", "eth1", True) in rows, rows
    assert ("wifi", "eth2", True) in rows, rows
    assert ("wifi", "eth3", True) in rows, rows
    out = machine.succeed("netpath check")
    assert "ok: lab wifi eth2" in out and "ok: lab wifi eth3" in out, out

    # the carrier is the policy route (dev + table), not the shadow address
    def route_via(dev):
        return f"ip route get 10.0.0.1 from 10.0.0.50 | grep 'dev {dev} table 100'"

    def router_maps(dev):
        mac = machine.succeed(f"cat /sys/class/net/{dev}/address").strip()
        return f"ip neigh show 10.0.0.50 | grep -qi {mac}"

    def ping_vip():
        machine.wait_until_succeeds("ping -q -c 1 -W 2 -I 10.0.0.50 10.0.0.1")

    # auto prefers the ethernet role
    machine.succeed("netpath auto")
    machine.wait_until_succeeds(route_via("eth1"))
    router.wait_until_succeeds("ip -4 addr show dev eth1 | grep -q 10.0.0.1", timeout=120)

    # role-wide wifi -> first ready card (eth2)
    machine.succeed("netpath wifi")
    machine.wait_until_succeeds(route_via("eth2"))
    router.wait_until_succeeds(router_maps("eth2"))
    ping_vip()

    # explicit card -> eth3
    machine.succeed("netpath wifi eth3")
    machine.wait_until_succeeds(route_via("eth3"))
    router.wait_until_succeeds(router_maps("eth3"))
    ping_vip()

    # explicit card back -> eth2
    machine.succeed("netpath wifi eth2")
    machine.wait_until_succeeds(route_via("eth2"))
    router.wait_until_succeeds(router_maps("eth2"))

    # back to ethernet
    machine.succeed("netpath ethernet")
    machine.wait_until_succeeds(route_via("eth1"))
    ping_vip()

    # guarded: explicit dead card fails, active path untouched
    machine.succeed("ip link set eth2 down")
    machine.fail("netpath wifi eth2")
    machine.wait_until_succeeds(route_via("eth1"))
    out = machine.succeed("netpath status")
    assert "active: lab ethernet" in out, out
    machine.succeed("ip link set eth2 up")

    # guarded: a card of the wrong role is rejected outright
    machine.fail("netpath wifi eth1")

    # sibling failover (new): active wifi/eth2, kill eth2 -> reconcile stays
    # within the wifi role on eth3, NOT the other role
    machine.succeed("netpath wifi eth2")
    machine.wait_until_succeeds(route_via("eth2"))
    machine.succeed("ip link set eth2 down")
    machine.wait_until_succeeds(route_via("eth3"), timeout=90)  # moved, deterministically, to eth3
    out = machine.succeed("netpath status")
    assert "active: lab wifi" in out, out  # same role, not ethernet
    ping_vip()
    machine.succeed("ip link set eth2 up")

    # fallback: active wifi/eth3, kill BOTH wifi cards -> drops to the
    # ethernet role. Drive reconcile manually (the VM timer is coarse);
    # assert on the authoritative state suffix first.
    machine.succeed("netpath wifi eth3")
    machine.wait_until_succeeds(route_via("eth3"))
    machine.succeed("ip link set eth2 down; ip link set eth3 down")
    machine.wait_until_succeeds(
        "netpath reconcile && netpath status | grep 'active: lab ethernet'",
        timeout=120,
    )
    machine.wait_until_succeeds(route_via("eth1"))
    ping_vip()
    machine.succeed("ip link set eth2 up; ip link set eth3 up")

    # off: VIP and policy state removed, ordinary routing restored
    machine.succeed("netpath off")
    machine.succeed("! ip -4 addr show | grep -q 10.0.0.50")
    machine.succeed("! ip rule show | grep -q '10000:'")

    # auto prefers ethernet when both roles are up
    machine.succeed("netpath auto")
    machine.wait_until_succeeds(route_via("eth1"))
    ping_vip()
  '';
}