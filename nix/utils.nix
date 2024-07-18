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

  gen-config-type-to = mappings: mkError: config-type:
    mappings.${config-type} or
      (builtins.throw
        (mkError config-type));

  config-type-to-outputs-machines =
    gen-config-type-to
      {
        nixos = "nixosMachines";
        nix-on-droid = "nixOnDroidMachines";
        nix-darwin = "nixDarwinMachines";
        home-manager = "homeMachines";
      }
      (config-type:
        builtins.throw
          "Invaild config-type \"${config-type}\" for flake outputs' machines");

  config-type-to-outputs-configurations =
    gen-config-type-to
      {
        nixos = "nixosConfigurations";
        nix-on-droid = "nixOnDroidConfigurations";
        nix-darwin = "darwinConfigurations";
        home-manager = "homeConfigurations";
      }
      (config-type:
        builtins.throw
          "Invaild config-type \"${config-type}\" for flake outputs' configurations");

  config-type-to-deploy-type =
    gen-config-type-to
      {
        nixos = "nixos";
        nix-darwin = "darwin";
      }
      (config-type:
        builtins.throw
          "Invaild config-type \"${config-type}\" for deploy-rs deployment");

  accumulateMachines = config-types: host-system-config-type-config-fn:
    lib.flip lib.concatMapAttrs
      (lib.genAttrs
        config-types
        (config-type:
          let
            machines = config-type-to-outputs-machines config-type;
          in
            self.${machines}))
      (config-type: machines:
        lib.pipe
          machines
          [
            # Filter out nondirectories
            (lib.filterAttrs
              (system: configs:
                builtins.isAttrs configs))
            # Convert non-template configs into `system-and-config` pairs
            (lib.concatMapAttrs
              (system: configs:
                (lib.concatMapAttrs
                  (host: config:
                    lib.optionalAttrs
                      (host != "__template__")
                      {
                        ${host} = {
                          inherit system;
                          config =
                            let
                              configurations = config-type-to-outputs-configurations config-type;
                            in
                              self.${configurations}.${host};
                        };
                      })
                  configs)))
            # Convert each `system-and-config` pair into a deploy-rs node
            (lib.concatMapAttrs
              (host: { system, config }:
                host-system-config-type-config-fn { inherit host system config-type config; }))
          ]);
}
