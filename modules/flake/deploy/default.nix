{ lib, config, self, inputs, ... }:

let
  inherit (config.lib)
    accumulateHosts
    configuration-type-to-deploy-type;
in
{
  flake = {
    deploy.nodes =
      accumulateHosts
        # TODO: nix-on-droid
        ["nixos" "nix-darwin"]
        ({ host, system, configuration-type, configuration }:
          let
            deploy-config-path =
              "${config.flake.autoConfigurations.${configuration-type}.dir}/${system}/${host}/deploy.nix";
            deploy-config =
              import deploy-config-path;
          in
            lib.optionalAttrs
              (builtins.pathExists deploy-config-path)
              {
                ${host} = {
                  inherit (deploy-config)
                  hostname;
                  profiles.system = deploy-config // {
                    path =
                      let
                        deploy-type = configuration-type-to-deploy-type configuration-type;
                      in
                        inputs.deploy-rs.lib.${system}.activate.${deploy-type} configuration;
                  };
                };
              }
        );

    checks =
      lib.mapAttrs
        (system: deployLib:
          deployLib.deployChecks
            self.deploy)
        inputs.deploy-rs.lib;
  };
}
