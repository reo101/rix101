{ lib, config, self, inputs, ... }:

{
  imports = [
    inputs.agenix-rekey.flakeModule
  ];

  perSystem = {
    agenix-rekey = {
      nodes = {
        inherit (self.nixosConfigurations) jeeves;
      };
    };
  };
}
