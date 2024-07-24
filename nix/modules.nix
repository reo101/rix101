{ lib, config, self, inputs, ... }:

let
  outputs = self;
  inherit (import ./utils.nix { inherit lib self; })
    eq
    and
    hasFiles
    camelToKebab;
in
let
  # Modules helpers
  moduleTypes = ["nixos" "nixOnDroid" "nixDarwin" "homeManager" "flake"];
  createModules = baseDir: { passthru ? { inherit inputs outputs; }, ... }:
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
        Automagivally generate modules from walking directories with Nix files
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
                        default = "${submodule.config.baseDir}/${camelToKebab moduleType}";
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
                lib.nameValuePair
                "${moduleType}Modules"
                (if config.flake.autoModules.${moduleType}.enable
                  then createModules config.flake.autoModules.${moduleType}.dir { }
                  else { })))
            builtins.listToAttrs
          ];
    in {
      # NOTE: manually inheriting generated modules to avoid recursion
      #       (`autoModules` depends on `config.flake` itself)
      inherit (autoModules)
        nixosModules
        nixOnDroidModules
        nixDarwinModules
        homeManagerModules
        flakeModules;
    };
  };
}
