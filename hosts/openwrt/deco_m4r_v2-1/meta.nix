{
  release = "25.12.0";
  profile = "tplink_deco-m4r-v1";
  cachePath = ../../../modules/flake/configurations/openwrt-cache/25.12.0;
  system = "x86_64-linux";

  # Managed by tofu: `nix run .#openwrt-tofu -- .#deco_m4r_v2-1 plan`
  openwrt = {
    remote = "http://192.168.1.2";
    secret = "home/openwrt/luci.age"; # shared admin password until per-host ones exist
    system = {
      hostname = "deco-m4r-1";
      timezone = "EET-2EEST,M3.5.0/3,M10.5.0/4";
      zonename = "Europe/Sofia";
      ntp = null; # AP: no NTP server role
    };
  };
}