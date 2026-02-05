{ pkgs, lib, ... }:

# TODO: meshing
let
  uci = lib.custom.uci;
  sshPubKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIL5ibKzd+V2eR1vmvBAfSWcZmPB8zUYFMAN3FS6xY9ma";

  uciBatchLines = [
    "# AP defaults"
    (uci.delete "dhcp.wan")
    (uci.set "dhcp.lan.ignore" "1")
    (uci.set "network.lan.ipaddr" "192.168.1.2")
    (uci.set "network.lan.gateway" "192.168.1.1")
    (uci.delete "network.lan.dns")
    (uci.addList "network.lan.dns" "192.168.1.1")
    (uci.set "system.@system[0].hostname" "deco-m4r")
    (uci.set "system.@system[0].zonename" "Europe/Sofia")
    (uci.set "system.@system[0].timezone" "EET-2EEST,M3.5.0/3,M10.5.0/4")
    (uci.set "dropbear.@dropbear[0].PasswordAuth" "off")
    (uci.set "dropbear.@dropbear[0].RootPasswordAuth" "off")
    (uci.set "uhttpd.main.redirect_https" "1")
    ""
    (uci.commit "network")
    (uci.commit "dhcp")
    (uci.commit "system")
    (uci.commit "dropbear")
    (uci.commit "uhttpd")
  ];

  uciDefaultsScript = ''
#!/usr/bin/env ash
set -eu

uci -q batch <<'UCI'
${uci.renderBatch uciBatchLines}
UCI
'';
in {
  extraImageName = "deco-m4r-ap";

  packages = [
    "luci" # https://github.com/astro/nix-openwrt-imagebuilder/issues/53
    "luci-ssl"
    "iperf3"
    "luci-app-advanced-reboot"
  ];

  files = pkgs.runCommand "image-files" {} ''
    mkdir -p $out/etc/dropbear
    echo "${sshPubKey}" > $out/etc/dropbear/authorized_keys

    mkdir -p $out/etc/uci-defaults
    cat > $out/etc/uci-defaults/99-custom <<'SCRIPT'
${uciDefaultsScript}
SCRIPT

    chmod +x $out/etc/uci-defaults/99-custom
  '';
}
