{ inputs, ... }:
{ lib, pkgs, config, ... }:

{
  imports = [ ];

  options = { };

  config = {
    # # Add flake inputs to $NIX_PATH
    # home.sessionVariables = {
    #   NIX_PATH =
    #     builtins.concatStringsSep
    #       ":"
    #       (lib.mapAttrsToList
    #         (name: input:
    #           "${name}=${input.sourceInfo.outPath}")
    #         inputs);
    # };

    # NOTE: now automatic, since we're doing `useGlobalPkgs = true`
    #
    # # Use flake overlays by default
    # nixpkgs = {
    #   overlays = lib.attrValues inputs.self.overlays;
    #
    #   config.allowUnfree = true;
    # };
  };
}
