{ lib, config, self, inputs, ... }:

let
  inherit (import ./utils.nix { inherit lib self; })
    accumulateMachines
    configuration-type-to-deploy-type;
in
{
  flake = {
    deploy.nodes =
      accumulateMachines
        # TODO: nix-on-droid
        ["nixos" "nix-darwin"]
        ({ host, system, configuration-type, configuration }:
          let
            deploy-config-path =
              ../machines/${configuration-type}/${system}/${host}/deploy.nix;
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
