{ lib, self, ... }:

rec {
  # Boolean helpers
  and = lib.all lib.id;
  or = lib.any lib.id;
  eq = x: y: x == y;

  # Directory walking helpers
  recurseDir = dir:
    lib.mapAttrs
      (file: type:
        if type == "directory"
        then recurseDir "${dir}/${file}"
        else type)
      (builtins.readDir dir);

  allSatisfy = predicate: attrs: attrset:
    lib.all
      (attr:
         and [
           (builtins.hasAttr attr attrset)
           (predicate (builtins.getAttr attr attrset))
         ])
      attrs;

  # NOTE: Implying last argument is the output of `recurseDir`
  hasFiles = allSatisfy (eq "regular");

  # NOTE: Implying last argument is the output of `recurseDir`
  hasDirectories = allSatisfy lib.isAttrs;

  camelToKebab =
    lib.stringAsChars
      (c: if c == lib.toUpper c then "-${lib.toLower c}" else c);

  # NOTE: from  Tweag's Nix Hour 76 - <https://github.com/tweag/nix-hour/blob/c4fd0f2fc3059f057571bbfd74f3c5e4021f526c/code/76/default.nix#L4-L22>
  mutFirstChar =
    f: s:
    let
      firstChar = f (lib.substring 0 1 s);
      rest = lib.substring 1 (-1) s;
    in firstChar + rest;

  kebabToCamel =
    s:
    mutFirstChar lib.toLower (
      lib.concatMapStrings (mutFirstChar lib.toUpper) (
        lib.splitString "-" s
      )
    );

  gen-configuration-type-to = mappings: mkError: configuration-type:
    mappings.${configuration-type} or
      (builtins.throw
        (mkError configuration-type));

  configuration-type-to-outputs-machines =
    gen-configuration-type-to
      {
        nixos = "nixosMachines";
        nix-on-droid = "nixOnDroidMachines";
        nix-darwin = "nixDarwinMachines";
        home-manager = "homeMachines";
      }
      (configuration-type:
        builtins.throw
          "Invaild configuration-type \"${configuration-type}\" for flake outputs' machines");

  configuration-type-to-outputs-configurations =
    gen-configuration-type-to
      {
        nixos = "nixosConfigurations";
        nix-on-droid = "nixOnDroidConfigurations";
        nix-darwin = "darwinConfigurations";
        home-manager = "homeConfigurations";
      }
      (configuration-type:
        builtins.throw
          "Invaild configuration-type \"${configuration-type}\" for flake outputs' configurations");

  configuration-type-to-deploy-type =
    gen-configuration-type-to
      {
        nixos = "nixos";
        nix-darwin = "darwin";
      }
      (configuration-type:
        builtins.throw
          "Invaild configuration-type \"${configuration-type}\" for deploy-rs deployment");

  accumulateMachines = configuration-types: host-system-configuration-type-configuration-fn:
    lib.flip lib.concatMapAttrs
      (lib.genAttrs
        configuration-types
        (configuration-type:
          let
            machines = configuration-type-to-outputs-machines configuration-type;
          in
            self.${machines}))
      (configuration-type: machines:
        lib.pipe
          machines
          [
            # Filter out nondirectories
            (lib.filterAttrs
              (system: configurations:
                builtins.isAttrs configurations))
            # Convert non-template configs into `system-and-config` pairs
            (lib.concatMapAttrs
              (system: configurations:
                (lib.concatMapAttrs
                  (host: configuration:
                    lib.optionalAttrs
                      (host != "__template__")
                      {
                        ${host} = {
                          inherit system;
                          configuration =
                            let
                              configurations = configuration-type-to-outputs-configurations configuration-type;
                            in
                              self.${configurations}.${host};
                        };
                      })
                  configurations)))
            # Convert each `system-and-config` pair into a *whatever*
            (lib.concatMapAttrs
              (host: { system, configuration }:
                host-system-configuration-type-configuration-fn { inherit host system configuration-type configuration; }))
          ]);
}
