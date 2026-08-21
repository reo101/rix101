{
  release = "25.12.0";
  profile = "asus_tuf-ax4200";
  cachePath = ../../../modules/flake/configurations/openwrt-cache/25.12.0;
  system = "x86_64-linux";

  openwrt = {
    host = "192.168.1.1";
    dryRun = false;
    pruneOrphans = true;
    secretFile = "secrets/master/home/openwrt/router-config.nix.age";
    reloadServices = [ "dnsmasq" ];
  };
}
