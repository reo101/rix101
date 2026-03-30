{ lib, ... }:
{
  system = "x86_64-linux";

  pubkey = lib.pipe ../../../secrets/master/home/iso/bootstrap/ssh_host_ed25519_key.pub [
    builtins.readFile
    lib.trim
  ];
}
