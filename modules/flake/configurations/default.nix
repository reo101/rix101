{ lib, config, self, inputs, withSystem, ... }:

{
  imports = [
    ../lib
    ./default-generators.nix
  ];

  options = let
    inherit (lib)
      types
      ;
    inherit (config.lib)
      recurseDir
      kebabToCamel
      ;
  in {
    auto.configurations = lib.mkOption {
      description = ''
        Automagically generate configurations from walking directories with Nix files
      '';
      internal = true;
      type = types.submodule (autoConfigurationsSubmodule: let
        inherit (autoConfigurationsSubmodule.config)
          configurationTypes
          enableAll
          baseDir
          ;
      in {
        options = {
          enableAll = lib.mkEnableOption ''
            Automatic ${builtins.toString (lib.attrValues configurationTypes)} configurations extraction
          '';
          baseDir = lib.mkOption {
            description = ''
              Base directory of the contained configurations, used as a base for the rest of the options
            '';
            type = types.path;
            default = "${self}/hosts";
            defaultText = ''''${self}/hosts'';
          };
          configurationTypes = lib.mkOption {
            type = types.attrsOf (types.submodule (configurationTypeSubmodule@{ name, ... }: let
              inherit (configurationTypeSubmodule.config)
                # enable
                dir
                predicate
                mkHost
                mkDeployNode
                ;
            in {
              options = {
                enable = lib.mkEnableOption "Automatic ${name} configurations extraction" // {
                  default = enableAll;
                };
                # NOTE: each can be read from a different directory
                dir = lib.mkOption {
                  type = types.path;
                  default = "${baseDir}/${name}";
                };
                hostsName = lib.mkOption {
                  description = ''
                    Name of the `hosts` output
                  '';
                  type = types.str;
                  default = "${kebabToCamel name}Hosts";
                };
                configurationsName = lib.mkOption {
                  description = ''
                    Name of the `configurations` output
                  '';
                  type = types.str;
                  default = "${kebabToCamel name}Configurations";
                };
                predicate = lib.mkOption {
                  description = ''
                    Function for filtering configurations
                  '';
                  # FIXME: `merge` of `functionTo` type causes a stray `passthru` to attempt getting evaluated
                  # type = types.functionTo types.anything;
                  type = types.unspecified;
                  example = /* nix */ ''
                    { root, host, configurationFiles, ... }:
                      # Utils from `./modules/flake/lib/default.nix`
                      and [
                        (! (host == "__template__"))
                        (hasFiles
                          [ "configuration.nix" ]
                          configurationFiles)
                        (hasDirectories
                          [ "home" ]
                          configurationFiles)
                      ]
                  '';
                };
                mkHost = lib.mkOption {
                  description = ''
                    Function for generating a configuration
                  '';
                  # type = types.functionTo types.anything;
                  type = types.unspecified;
                  example = /* nix */ ''
                    args @ { root, meta, users }: inputs.nixpkgs.lib.nixosSystem {
                      inherit (meta) system;

                      modules = [
                        # Main configuration
                        "''${root}/configuration.nix"
                        # Home Manager
                        inputs.home-manager.nixosModules.home-manager
                        (homeManagerModule args)
                      ] ++ (builtins.attrValues config.flake.''${configuration-type-to-outputs-modules "nixos"});

                      specialArgs = {
                        inherit inputs;
                        inherit meta;
                      };
                    };
                  '';
                };
                mkDeployNode = lib.mkOption {
                  description = ''
                    Function for generating a `deploy-rs` node (null to skip)
                  '';
                  type = types.nullOr (types.functionTo types.anything);
                  default = null;
                  # TODO: update
                  example = /* nix */ ''
                    { root, host, meta, configuration }: {
                      inherit (meta.deploy) hostname;
                      profiles.system = meta.deploy // {
                        path = inputs.deploy-rs.lib.''${meta.system}.activate."nixos" configuration;
                      };
                    }
                  '';
                };
                result = lib.mkOption {
                  description = ''
                    The resulting automatic host && deploy-rs configurations
                  '';
                  # TODO: specify
                  type = types.unspecified;
                  readOnly = true;
                  default =
                    lib.pipe dir [
                      recurseDir
                      (lib.concatMapAttrs
                        (host: configurationFiles:
                          let
                            root = "${dir}/${host}";
                            meta-path = "${root}/meta.nix";
                            meta = (lib.evalModules {
                              class = "meta";
                              modules = [
                                (if builtins.pathExists meta-path
                                 then import meta-path
                                 else {})
                                ./meta-module.nix
                                {
                                  config = {
                                    enable = lib.mkDefault (host != "__template__");
                                    hostname = lib.mkDefault host;
                                  };
                                }
                              ];
                            }).config;
                            deploy-config = meta.deploy;
                            has-mkDeployNode = mkDeployNode != null;
                            has-deploy-config = deploy-config != null;
                            configuration-args = { inherit root meta configurationFiles; };
                            valid = predicate configuration-args;
                            configuration = mkHost configuration-args;
                            deploy-args = { inherit root meta configuration; };
                            deploy = mkDeployNode deploy-args;
                          in
                            lib.optionalAttrs valid {
                              ${host} = {
                                inherit configuration;
                              } // lib.optionalAttrs (has-mkDeployNode && has-deploy-config) {
                                inherit deploy;
                              };
                            }))
                    ];
                };
              };
            }));
            default = {};
          };
          result = lib.mkOption {
            readOnly = true;
            default = {
              configurations =
                lib.pipe configurationTypes [
                  (lib.mapAttrs'
                    (configurationType: configurationTypeConfig:
                      lib.nameValuePair
                      configurationTypeConfig.configurationsName
                      (lib.mapAttrs
                        (host: { configuration, ... }:
                          configuration)
                        configurationTypeConfig.result)))
                ];
              deployNodes =
                lib.pipe configurationTypes [
                  (lib.concatMapAttrs
                    (configurationType: configurationTypeConfig:
                      (lib.concatMapAttrs
                        (host: { deploy ? null, ... }:
                          lib.optionalAttrs
                          (deploy != null)
                          {
                            ${host} = deploy;
                          })
                        configurationTypeConfig.result)))
                ];
            };
          };
        };
      });
      default = {};
    };
  };

  config = {
    flake = let
      configurations = config.auto.configurations.result.configurations;
      deployNodes = {
        deploy.nodes = config.auto.configurations.result.deployNodes;
      };
      deployChecks = {
        checks =
          lib.mapAttrs
            (system: deployLib:
              deployLib.deployChecks
              self.deploy)
            inputs.deploy-rs.lib;
      };
      # TODO: lib.something for merging (asserting for no overwrites)
    in configurations // deployNodes // deployChecks;
  };
}
