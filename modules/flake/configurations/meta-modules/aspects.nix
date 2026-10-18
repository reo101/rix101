{
  inputs,
  lib,
  configurationType,
  ...
}:

let
  providerType = (inputs.flake-aspects.lib lib).types.providerType { };
  selectionType = lib.types.listOf providerType;
in
{
  options = {
    aspects = lib.mkOption {
      type = selectionType;
      default = [ ];
      description = "Aspect providers selected for this configuration.";
    };
  }
  //
    lib.optionalAttrs
      (builtins.elem configurationType [
        "nixos"
        "nix-darwin"
        "nix-on-droid"
      ])
      {
        users = lib.mkOption {
          type = lib.types.attrsOf (
            lib.types.submodule {
              options.aspects = lib.mkOption {
                type = selectionType;
                default = [ ];
                description = "Aspect providers bound to this user's Home Manager configuration.";
              };
            }
          );
          default = { };
          description = "Named user profiles and their system and Home Manager aspects.";
        };
      };
}
