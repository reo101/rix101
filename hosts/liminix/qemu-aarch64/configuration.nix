# Liminix configuration for the qemu-aarch64 test device.
#
# Liminix configs are NixOS-style modules evaluated with Liminix's own
# evalModules (busybox + musl + s6-rc, no systemd). See:
#   https://github.com/telent/liminix (examples/hello-from-qemu.nix)
{
  config,
  pkgs,
  lib,
  modulesPath,
  ...
}:
let
  svc = config.system.service;
in
{
  imports = [ "${modulesPath}/network" ];

  hostname = "liminix-qemu";

  # internal LAN (the qemu device's `lan` interface)
  services.int = svc.network.address.build {
    interface = config.hardware.networkInterfaces.lan;
    family = "inet";
    address = "10.3.0.1";
    prefixLength = 16;
  };

  # root password is "secret" (mkpasswd -m sha512crypt)
  users.root.passwd =
    "$6$y7WZ5hM6l5nriLmo$5AJlmzQZ6WA.7uBC7S8L4o19ESR28Dg25v64/vDvvCN01Ms9QoHeGByj8lGlJ4/b.dbwR9Hq2KXurSnLigt1W1";

  defaultProfile.packages = with pkgs; [ figlet ];
}