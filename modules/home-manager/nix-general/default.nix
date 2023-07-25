{ inputs, outputs, ... }:
{ lib, pkgs, config, ... }:

{
  imports = [ ];

  options = { };

  config = {
    # Add flake inputs to $NIX_PATH
    home.sessionVariables = {
      NIX_PATH =
        builtins.concatStringsSep
          ":"
          (lib.mapAttrsToList
            (name: input:
              "${name}=${input.sourceInfo.outPath}")
            inputs);
    };

    # Use flake overlays by default
    nixpkgs = {
      overlays = lib.attrValues outputs.overlays;

      config.allowUnfree = true;
    };
  };
}
