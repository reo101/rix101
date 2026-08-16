{
  release = "25.12.0";
  profile = "asus_tuf-ax4200";
  cachePath = ../../../modules/flake/configurations/openwrt-cache/25.12.0;
  system = "x86_64-linux";

  # Managed by tofu: see `nix run .#openwrt-tofu -- .#asus_tuf-ax4200 plan`
  openwrt = {
    remote = "http://192.168.1.1";
    secret = "home/openwrt/luci.age";
    system = {
      hostname = "OpenWrt";
      timezone = "EET-2EEST,M3.5.0/3,M10.5.0/4";
      zonename = "Europe/Sofia";
      ntp = [
        "0.openwrt.pool.ntp.org"
        "1.openwrt.pool.ntp.org"
        "2.openwrt.pool.ntp.org"
        "3.openwrt.pool.ntp.org"
      ];
    };
  };
}