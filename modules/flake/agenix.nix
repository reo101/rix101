{ lib, config, self, inputs, ... }:

{
  imports = [
    inputs.agenix-rekey.flakeModule
  ];

  perSystem = {
    agenix-rekey = {
      nodes = self.nixosConfigurations;
    };
  };
}
