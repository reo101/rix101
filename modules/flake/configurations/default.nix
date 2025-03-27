{ lib, config, self, inputs, withSystem, ... }:

{
  imports = [
    ../lib
    ../lib-custom
    ./default-generators.nix
  ];

  options = let
    inherit (lib)
      types
      ;
    inherit (config.lib)
      extractNixFile
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
            # TODO: better merging (test on separate flake)
            type = types.attrsOf (types.submodule (configurationTypeSubmodule@{ name, ... }: let
              inherit (configurationTypeSubmodule.config)
                # enable
                dir
                predicate
                metaModule
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
                    { host, configurationFiles, ... }:
                      # Utils from `./modules/flake/lib/default.nix`
                      and [
                        (! (host == "__template__"))
                        (hasNixFiles
                          [ "configuration.nix" ]
                          configurationFiles)
                        (hasDirectories
                          [ "home" ]
                          configurationFiles)
                      ]
                  '';
                };
                metaModule = lib.mkOption {
                  description = ''
                    Module to be included in the `meta` computation
                    Has access to the `metaModules` module argument for access to common meta modules
                  '';
                  type = types.deferredModule;
                  default = {};
                };
                # TODO: export common (simple) `mkHost`s?
                mkHost = lib.mkOption {
                  description = ''
                    Function for generating a configuration
                  '';
                  # type = types.functionTo types.anything;
                  type = types.unspecified;
                  example = /* nix */ ''
                    args @ { meta, configuration, users }: inputs.nixpkgs.lib.nixosSystem {
                      inherit (meta) system;

                      modules = [
                        # Main configuration
                        configuration
                        # Home Manager
                        inputs.home-manager.nixosModules.home-manager
                      ] ++ (builtins.attrValues config.flake.nixosModules);

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
                  example = /* nix */ ''
                    { meta, configuration }: {
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
                      # Leave out only the directories
                      (lib.concatMapAttrs
                        (file: value:
                          lib.optionalAttrs
                            (value._type == "directory")
                            {
                              ${file} = value.content;
                            }))
                      (lib.concatMapAttrs
                        (host: configurationFiles:
                          let
                            meta-file = extractNixFile configurationFiles "meta.nix";
                            has-meta = meta-file != null;
                            meta-content = meta-file.content;
                            meta = (lib.evalModules {
                              class = "meta";
                              specialArgs = {
                                # Give access to common meta modules
                                metaModules = (import ./meta-modules);
                                # Pass through host (default for `hostname`, etc.)
                                inherit host;
                              };
                              modules = [
                                # {} if no `metaModule` is provided
                                metaModule
                                # {} if no `meta.nix` is provided
                                (lib.optionalAttrs has-meta meta-content)
                              ];
                            }).config;
                            deploy-config = meta.deploy or null;
                            has-deploy-config = deploy-config != null;
                            has-mkDeployNode = mkDeployNode != null;
                            configuration-args = { inherit meta configurationFiles; };
                            valid = predicate configuration-args;
                            configuration = mkHost configuration-args;
                            deploy-args = { inherit meta configuration; };
                            deploy = mkDeployNode deploy-args;
                          in
                            lib.optionalAttrs valid {
                              ${host} = {
                                inherit configuration;
                                inherit meta;
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
                        (host: { configuration, meta, ... }:
                          configuration // {
                            # NOTE: for introspection
                            inherit meta;
                          })
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
