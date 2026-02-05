{ pkgs, lib, ... }:

let
  inherit (lib.custom) uci;

  # TODO: store own pubkeys globally somehow
  sshPubKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIL5ibKzd+V2eR1vmvBAfSWcZmPB8zUYFMAN3FS6xY9ma";

  lanPorts = [ "lan1" "lan2" "lan3" "lan4" ];

  inherit (lib.custom.rageImportEncrypted ./secrets.nix.age)
    lanSettings
    lanIp6Classes
    wanSettings
    wirelessNetworks
    wirelessExtraIfaces
    dnsmasqRebindDomains
    dnsmasqAddressRedirects
    staticLeases
    staticDomains
    firewallWanNetworks
    firewallRedirects
    dropbearConfig
    ;

  dnsmasqSettings = {
    domainneeded = "1";
    localise_queries = "1";
    rebind_protection = "1";
    rebind_localhost = "1";
    local = "/lan/";
    domain = "lan";
    expandhosts = "1";
    cachesize = "1000";
    readethers = "1";
    leasefile = "/tmp/dhcp.leases";
    resolvfile = "/tmp/resolv.conf.d/resolv.conf.auto";
    localservice = "0";
    ednspacket_max = "1232";
    confdir = "/tmp/dnsmasq.d";
    localuse = "1";
    listen_address = "127.0.0.1";
  };

  buildNamedSectionLines = {
    package,
    sectionType,
    entries,
    prefix ? "",
  }:
    lib.concatMap
      (name: let
        sectionName = "${prefix}${name}";
      in
      [
        (uci.setRaw "${package}.${sectionName}" sectionType)
      ]
      ++ lib.mapAttrsToList
        (key: value: uci.set "${package}.${sectionName}.${key}" value)
        entries.${name})
      (builtins.attrNames entries);

  wirelessPrimaryLines = lib.concatMap
    (radio: let
      cfg = wirelessNetworks.${radio};
    in
    (lib.mapAttrsToList
      (key: value: uci.set "wireless.${radio}.${key}" value)
      cfg.radio)
    ++ (lib.mapAttrsToList
      (key: value: uci.set "wireless.default_${radio}.${key}" value)
      cfg.iface))
    (builtins.attrNames wirelessNetworks);

  wirelessExtraIfaceLines = lib.concatMap
    (ifaceName: let
      ifaceConfig = wirelessExtraIfaces.${ifaceName};
      sectionType = ifaceConfig.__type or "wifi-iface";
      attrs = lib.removeAttrs ifaceConfig [ "__type" ];
    in
    [
      (uci.setRaw "wireless.${ifaceName}" sectionType)
    ]
    ++ lib.mapAttrsToList
      (key: value: uci.set "wireless.${ifaceName}.${key}" value)
      attrs)
    (builtins.attrNames wirelessExtraIfaces);

  uciBatchLines = lib.concatLists [
    # Reset bridge port list before re-populating it
    [
      "# Network"
      (uci.delete "network.@device[0].ports")
    ]
    # Add all LAN bridge member ports
    (lib.map (port: uci.addList "network.@device[0].ports" port) lanPorts)
    # Apply LAN interface settings from secrets
    (lib.mapAttrsToList (key: value: uci.set "network.lan.${key}" value) lanSettings)
    # Reset IPv6 class list before custom values
    [
      (uci.delete "network.lan.ip6class")
    ]
    # Add LAN IPv6 class entries
    (lib.map (ip6class: uci.addList "network.lan.ip6class" ip6class) lanIp6Classes)
    # Apply WAN settings except DNS (handled as a list below)
    (lib.mapAttrsToList
      (key: value: uci.set "network.wan.${key}" value)
      (lib.removeAttrs wanSettings [ "dns" ]))
    # Reset WAN DNS list before adding configured resolvers
    [ (uci.delete "network.wan.dns") ]
    # Add WAN DNS resolvers
    (lib.map (dns: uci.addList "network.wan.dns" dns) wanSettings.dns)
    # Define fallback WWAN and WAN6 behavior
    [
      (uci.setRaw "network.wwan" "interface")
      (uci.set "network.wwan.proto" "dhcp")
      (uci.set "network.wan6.proto" "dhcpv6")
      (uci.set "network.wan6.device" "@wan")
      (uci.set "network.wan6.reqaddress" "try")
      (uci.set "network.wan6.reqprefix" "auto")
      ""
      "# Wireless"
    ]
    # Configure primary radio + default iface pairs
    wirelessPrimaryLines
    [
      ""
    ]
    # Configure additional named wireless interfaces
    wirelessExtraIfaceLines
    [
      ""
      "# DHCP and local DNS"
    ]
    # Apply core dnsmasq options
    (lib.mapAttrsToList (key: value: uci.set "dhcp.@dnsmasq[0].${key}" value) dnsmasqSettings)
    # Reset and rebuild rebind domain allowlist
    [
      (uci.delete "dhcp.@dnsmasq[0].rebind_domain")
    ]
    # Add rebind-domain exceptions
    (lib.map (domain: uci.addList "dhcp.@dnsmasq[0].rebind_domain" domain) dnsmasqRebindDomains)
    # Reset and rebuild dnsmasq address redirects
    [
      (uci.delete "dhcp.@dnsmasq[0].address")
    ]
    # Add dnsmasq domain-to-IP redirects
    (lib.map
      ({ domain, ip }: uci.addList "dhcp.@dnsmasq[0].address" "/${domain}/${ip}")
      dnsmasqAddressRedirects)
    # Apply LAN/WAN DHCP and odhcpd baseline settings
    [
      (uci.set "dhcp.lan.interface" "lan")
      (uci.set "dhcp.lan.start" "100")
      (uci.set "dhcp.lan.limit" "150")
      (uci.set "dhcp.lan.leasetime" "12h")
      (uci.set "dhcp.lan.dhcpv4" "server")
      (uci.set "dhcp.lan.dhcpv6" "server")
      (uci.set "dhcp.lan.ra" "server")
      (uci.delete "dhcp.lan.ra_flags")
      (uci.addList "dhcp.lan.ra_flags" "managed-config")
      (uci.addList "dhcp.lan.ra_flags" "other-config")
      (uci.delete "dhcp.lan.dhcp_option")
      (uci.addList "dhcp.lan.dhcp_option" "6,192.168.1.1")
      (uci.set "dhcp.wan.interface" "wan")
      (uci.set "dhcp.wan.ignore" "1")
      (uci.set "dhcp.odhcpd.maindhcp" "0")
      (uci.set "dhcp.odhcpd.leasefile" "/tmp/odhcpd.leases")
      (uci.set "dhcp.odhcpd.leasetrigger" "/usr/sbin/odhcpd-update")
      (uci.set "dhcp.odhcpd.loglevel" "4")
      (uci.set "dhcp.odhcpd.piodir" "/tmp/odhcpd-piodir")
      (uci.set "dhcp.odhcpd.hostsdir" "/tmp/hosts")
      ""
      "# Static leases and hostnames"
    ]
    # Materialize static DHCP host sections
    (buildNamedSectionLines {
      package = "dhcp";
      sectionType = "host";
      prefix = "host_";
      entries = staticLeases;
    })
    # Materialize static local DNS domain records
    (lib.concatMap
      (domainName: [
        (uci.setRaw "dhcp.domain_${domainName}" "domain")
        (uci.set "dhcp.domain_${domainName}.name" domainName)
        (uci.set "dhcp.domain_${domainName}.ip" staticDomains.${domainName})
      ])
      (builtins.attrNames staticDomains))
    # Reset WAN zone network bindings to a known set
    [
      ""
      "# Firewall: keep wwan in WAN zone, and restore forwards"
      (uci.delete "firewall.@zone[1].network")
    ]
    # Add WAN-zone member networks
    (lib.map (network: uci.addList "firewall.@zone[1].network" network) firewallWanNetworks)
    # Materialize custom firewall redirect rules
    (buildNamedSectionLines {
      package = "firewall";
      sectionType = "redirect";
      prefix = "redirect_";
      entries = firewallRedirects;
    })
    # Apply system defaults and reset NTP server list
    [
      ""
      "# System/UI/SSH"
      (uci.set "system.@system[0].hostname" "OpenWrt")
      (uci.set "system.@system[0].timezone" "EET-2EEST,M3.5.0/3,M10.5.0/4")
      (uci.set "system.@system[0].zonename" "Europe/Sofia")
      (uci.set "system.@system[0].log_proto" "udp")
      (uci.set "system.@system[0].conloglevel" "8")
      (uci.set "system.@system[0].cronloglevel" "5")
      (uci.delete "system.ntp.server")
    ]
    # Add OpenWrt pool NTP servers (0..3)
    (lib.genList (n: uci.addList "system.ntp.server" "${builtins.toString n}.openwrt.pool.ntp.org") 4)
    # Dropbear configuration
    (lib.mapAttrsToList
      (key: value: uci.set "dropbear.@dropbear[0].${key}" value)
      dropbearConfig)
    # Uhttpd
    [
      (uci.set "uhttpd.main.redirect_https" "0")
    ]
    # Package commits
    [
      ""
      (uci.commit "network")
      (uci.commit "wireless")
      (uci.commit "dhcp")
      (uci.commit "firewall")
      (uci.commit "system")
      (uci.commit "dropbear")
      (uci.commit "uhttpd")
    ]
  ];

  uciDefaultsScript = ''
#!/usr/bin/env ash
set -eu

uci -q batch <<'UCI'
${uci.renderBatch uciBatchLines}
UCI
'';
in
{
  packages = [
    "luci" # https://github.com/astro/nix-openwrt-imagebuilder/issues/53
    "luci-ssl"
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
