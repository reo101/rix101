{ lib, config, self, inputs, ... }:

let
  inherit (import ../../nix/utils.nix { inherit lib config self; })
    eq
    and
    hasFiles
    configuration-type-to-outputs-modules;
in
let
  # Modules helpers
  moduleTypes = ["nixos" "nix-on-droid" "nix-darwin" "home-manager" "flake"];

  createModules = baseDir: { passthru ? { inherit inputs; }, ... }:
    lib.pipe baseDir [
      # Read given directory
      builtins.readDir
      # Map each entry to a module
      (lib.mapAttrs'
        (name: type:
          let
            # BUG: cannot use `append` because of `${self}` (not a path)
            # moduleDir = lib.path.append baseDir "${name}";
            moduleDir = "${baseDir}/${name}";
          in
          if and [
            (type == "directory")
            (hasFiles [ "default.nix" ] (builtins.readDir moduleDir))
          ] then
            # Classic module in a directory
            lib.nameValuePair
              name
              (import moduleDir)
          else if and [
            (type == "regular")
            (lib.hasSuffix ".nix" name)
          ] then
            # Classic module in a file
            lib.nameValuePair
              (lib.removeSuffix ".nix" name)
              (import moduleDir)
          else
            # Invalid module
            lib.nameValuePair
              name
              null))
      # Filter invalid modules
      (lib.filterAttrs
        (moduleName: module:
          module != null))
      # Passthru if needed
      (lib.mapAttrs
        (moduleName: module:
          if and [
            (builtins.isFunction
              module)
            # FIXME: check for subset, not `eq`
            (eq
              (lib.pipe module [ builtins.functionArgs builtins.attrNames ])
              (lib.pipe passthru [ builtins.attrNames ]))
          ]
          then module passthru
          else module))
    ];
in
{
  options = let
    inherit (lib) types;
  in {
    flake.autoModules = lib.mkOption {
      description = ''
        Automagically generate modules from walking directories with Nix files
      '';
      type = types.submodule (submodule: {
        options = {
          enableAll = lib.mkEnableOption "Automatic ${builtins.toString moduleTypes} modules extraction";
          baseDir = lib.mkOption {
            description = ''
              Base directory of the contained modules, used as a base for the rest of the options
            '';
            type = types.path;
            default = "${self}/modules";
            defaultText = ''''${self}/modules'';
          };
        } // (
          lib.pipe
          moduleTypes
          [
            (builtins.map
              # NOTE: create small submodule for every `moduleType`
              (moduleType:
                lib.nameValuePair
                "${moduleType}"
                (lib.mkOption {
                  type = types.submodule {
                    options = {
                      # NOTE: each can be enabled (default global `enableAll`)
                      enable = lib.mkEnableOption "Automatic ${moduleType} modules extraction" // {
                        default = submodule.config.enableAll;
                      };
                      # NOTE: each can be read from a different directory
                      # (default global `baseDir` + `camelToKebab`-ed `moduleType`)
                      dir = lib.mkOption {
                        type = types.path;
                        default = "${submodule.config.baseDir}/${moduleType}";
                      };
                      result = lib.mkOption {
                        description = ''
                          The resulting automatic packages
                        '';
                        # TODO: specify
                        type = types.unspecified;
                        readOnly = true;
                        internal = true;
                        default =
                          lib.optionalAttrs
                            config.flake.autoModules.${moduleType}.enable
                            (createModules config.flake.autoModules.${moduleType}.dir { });
                      };
                    };
                  };
                  default = {};
                })))
            builtins.listToAttrs
          ]);
      });
      default = {};
    };
  };

  config = {
    flake = let
      autoModules =
        lib.pipe
          moduleTypes
          [
            (builtins.map
              (moduleType:
                let
                  name = "${configuration-type-to-outputs-modules moduleType}";
                  value = config.flake.autoModules.${moduleType}.result;
                in
                  lib.nameValuePair name value))
            builtins.listToAttrs
          ];
    in autoModules;
  };
}
