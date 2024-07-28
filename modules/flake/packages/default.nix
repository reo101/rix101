{ lib, config, self, inputs, ... }:

let
  inherit (import ../../../nix/utils.nix { inherit lib config self; })
    eq
    and
    hasFiles;
in
let
  createPackages = baseDir: { passthru ? { inherit inputs; }, ... }:
    lib.pipe baseDir [
      # Read given directory
      builtins.readDir
      # Map each entry to a package
      (lib.mapAttrs'
        (name: type:
          let
            packageDir = "${baseDir}/${name}";
            systems = let
              systemsPath = "${baseDir}/${name}/systems.nix";
            in
              # NOTE: If the package can restrict for which systems it wants to be built
              if builtins.pathExists systemsPath
              then import systemsPath
              else lib.const true;
            package = import packageDir;
            result = {
              inherit package systems;
            };
          in
          if and [
            (type == "directory")
            (hasFiles [ "default.nix" ] (builtins.readDir packageDir))
          ] then
            # NOTE: Classic package in a directory
            lib.nameValuePair
              name
              result
          else if and [
            (type == "regular")
            (lib.hasSuffix ".nix" name)
          ] then
            # NOTE: Classic package in a file
            lib.nameValuePair
              (lib.removeSuffix ".nix" name)
              result
          else
            # NOTE: Invalid package
            lib.nameValuePair
              name
              null))
      # Filter invalid packages
      (lib.filterAttrs
        (packageName: package:
          package != null))
      # Passthru if needed
      (lib.mapAttrs
        (packageName: package:
          if and [
            (builtins.isFunction
              package)
            (eq
              (lib.pipe package [ builtins.functionArgs builtins.attrNames ])
              (lib.pipe passthru [ builtins.attrNames ]))
          ]
          then package passthru
          else package))
    ];
in
{
  options = let
    inherit (lib) types;
  in {
    flake.autoPackages = lib.mkOption {
      description = ''
        Automagically generate packages from walking directories with Nix files
      '';
      type = types.submodule (submodule: {
        options = {
          enable = lib.mkEnableOption "Automatic packages extraction";
          dir = lib.mkOption {
            description = ''
              Base directory of the contained packages
            '';
            type = types.path;
            default = "${self}/pkgs";
            defaultText = ''''${self}/pkgs'';
          };
          result = lib.mkOption {
            description = ''
              The resulting automatic packages
            '';
            type = types.attrsOf (types.submodule { options = {
              package = lib.mkOption { type = types.unspecified; };
              systems = lib.mkOption { type = types.functionTo types.bool; };
            };});
            readOnly = true;
            internal = true;
            default =
              lib.optionalAttrs
                config.flake.autoPackages.enable
                (createPackages config.flake.autoPackages.dir { });
          };
        };
      });
      default = {};
    };
  };

  config = {
    perSystem = { lib, pkgs, system, ... }: let
      packages =
        lib.pipe
          config.flake.autoPackages.result
          [
            (lib.filterAttrs
              (name: { package, systems }:
                pkgs.callPackage systems {
                  inherit (pkgs) lib hostPlatform targetPlatform;
                }))
            (lib.mapAttrs
              (name: { package, systems }:
                pkgs.callPackage package { }))
          ];
    in {
      inherit packages;
    };
  };
}
