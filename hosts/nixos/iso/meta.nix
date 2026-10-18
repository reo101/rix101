{ lib, aspects, ... }:
{
  system = "x86_64-linux";

  users.reo101.aspects = [ aspects.standardEnvironment ];

  pubkey = lib.pipe ../../../secrets/master/home/iso/bootstrap/ssh_host_ed25519_key.pub [
    builtins.readFile
    lib.trim
  ];
}
