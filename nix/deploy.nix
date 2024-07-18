{ lib, config, self, inputs, ... }:

let
  inherit (import ./utils.nix { inherit lib self; })
    accumulateMachines
    config-type-to-deploy-type;
in
{
  flake = {
    deploy.nodes =
      accumulateMachines
        # TODO: nix-on-droid
        ["nixos" "nix-darwin"]
        ({ host, system, config-type, config }:
          let
            deploy-config-path =
              ../machines/${config-type}/${system}/${host}/deploy.nix;
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
                        deploy-type = config-type-to-deploy-type config-type;
                      in
                        inputs.deploy-rs.lib.${system}.activate.${deploy-type} config;
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
