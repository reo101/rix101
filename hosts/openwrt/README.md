# OpenWrt hosts

Router firmware hosts under `./hosts/openwrt/...` are built with
[nix-openwrt-imagebuilder]: packages plus a first-boot `uci-defaults` script
generated from Nix; build with `nix build .#configurations.openwrt.<host>`.

[nix-openwrt-imagebuilder]: https://github.com/astro/nix-openwrt-imagebuilder