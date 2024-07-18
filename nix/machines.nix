{ lib, config, self, inputs, ... }:

let
  inherit (import ./utils.nix { inherit lib self; })
    recurseDir;
in
let
  machines = recurseDir ../machines;
in
{
  flake = {
    # Machines
    nixosMachines       = machines.nixos        or { };
    nixDarwinMachines   = machines.nix-darwin   or { };
    nixOnDroidMachines  = machines.nix-on-droid or { };
    homeManagerMachines = machines.home-manager or { };
  };
}
