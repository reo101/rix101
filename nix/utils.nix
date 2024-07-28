{ lib, config, self, ... }:

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

  # NOTE: from Tweag's Nix Hour 76 - <https://github.com/tweag/nix-hour/blob/c4fd0f2fc3059f057571bbfd74f3c5e4021f526c/code/76/default.nix#L4-L22>
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

  # TODO: abstract away `_Hosts` and `_Modules`

  configuration-type-to-outputs-hosts =
    gen-configuration-type-to
      {
        nixos = "nixosHosts";
        nix-on-droid = "nixOnDroidHosts";
        nix-darwin = "darwinHosts";
        home-manager = "homeManagerHosts";
      }
      (configuration-type:
        builtins.throw
          "Invaild configuration-type \"${configuration-type}\" for flake outputs' hosts");

  configuration-type-to-outputs-modules =
    gen-configuration-type-to
      {
        nixos = "nixosModules";
        nix-on-droid = "nixOnDroidModules";
        nix-darwin = "darwinModules";
        home-manager = "homeManagerModules";
        flake = "flakeModules";
      }
      (configuration-type:
        builtins.throw
          "Invaild configuration-type \"${configuration-type}\" for flake outputs' modules");

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

  accumulateHosts = configuration-types: host-system-configuration-type-configuration-fn:
    lib.flip lib.concatMapAttrs
      (lib.genAttrs
        configuration-types
        (configuration-type:
          config.flake.autoConfigurations.${configuration-type}.resultHosts))
      (configuration-type: hosts:
        lib.pipe
          hosts
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
