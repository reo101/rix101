{ lib, config, self, inputs, ... }:

let
  modules = [
    {
    }
  ];
in
{
  imports = [
    inputs.nix-topology.flakeModule
  ];

  perSystem = {
    topology = {
      inherit modules;
      nixosConfigurations = {
        inherit (self.nixosConfigurations)
          jeeves;
      };
    };
  };
}
