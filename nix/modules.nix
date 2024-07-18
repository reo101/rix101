{ lib, config, self, inputs, ... }:

let
  outputs = self;
  inherit (import ./utils.nix { inherit lib self; })
    eq
    and
    hasFiles;
in
let
  # Modules helpers
  createModules = baseDir: { passthru ? { inherit inputs outputs; }, ... }:
    lib.pipe baseDir [
      # Read given directory
      builtins.readDir
      # Map each entry to a module
      (lib.mapAttrs'
        (name: type:
          let
            moduleDir = lib.path.append baseDir "${name}";
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
  flake = {
    # Modules
    nixosModules       = createModules ../modules/nixos        { };
    nixOnDroidModules  = createModules ../modules/nix-on-droid { };
    nixDarwinModules   = createModules ../modules/nix-darwin   { };
    homeManagerModules = createModules ../modules/home-manager { };
    flakeModules       = createModules ../modules/flake        { };
  };
}
