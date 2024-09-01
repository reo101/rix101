{ lib, config, self, inputs, withSystem, ... }:

let
  inherit (config.lib)
    and
    hasFiles
    hasDirectories
    recurseDir
    kebabToCamel
    configuration-type-to-outputs-modules;
in
let
  # Configuration helpers

  # `pkgs` with flake's overlays
  # NOTE: done here to avoid infinite recursion
  pkgs' = system:
    (withSystem system ({ pkgs, ... }: pkgs)).extend
      (final: prev: inputs.self.packages.${system});

  genUsers = configurationFiles:
    lib.pipe configurationFiles [
      (cf: cf."home" or { })
      builtins.attrNames
      (builtins.map
        (lib.strings.removeSuffix ".nix"))
    ];

  homeManagerModule = { root, meta, users ? null }: {
    home-manager = {
      # Use same `pkgs` instance as system (i.e. carry over overlays)
      useGlobalPkgs = true;
      # Do not keep packages in ${HOME}
      useUserPackages = true;
      # Default import all of our exported `home-manager` modules
      sharedModules = builtins.attrValues config.flake.${configuration-type-to-outputs-modules "home-manager"};
      # Pass in `inputs`, `hostname` and `meta`
      extraSpecialArgs = {
        inherit inputs;
        inherit meta;
      };
    } // (if users == null then {
      # nixOnDroid
      config = "${root}/home.nix";
    } else {
      # Not nixOnDroid
      users =
        lib.attrsets.genAttrs
          users
          (user: import "${root}/home/${user}.nix");
    });
  };

  mkNixosHost = args @ { root, meta, users }: inputs.nixpkgs.lib.nixosSystem {
    inherit (meta) system;
    pkgs = pkgs' meta.system;

    modules = [
      # Main configuration
      "${root}/configuration.nix"
      # Home Manager
      inputs.home-manager.nixosModules.home-manager
      (homeManagerModule args)
      # (r)agenix && agenix-rekey
      inputs.ragenix.nixosModules.default
      inputs.agenix-rekey.nixosModules.default
      # nix-topology
      inputs.nix-topology.nixosModules.default
      # Sane default `networking.hostName`
      {
        networking.hostName = lib.mkDefault meta.hostname;
      }
         # TODO: lib.optionals
    ] ++ (builtins.attrValues config.flake.${configuration-type-to-outputs-modules "nixos"});

    specialArgs = {
      inherit inputs;
      inherit meta;
    };
  };

  mkNixOnDroidHost = args @ { root, meta }: inputs.nix-on-droid.lib.nixOnDroidConfiguration {
    # NOTE: inferred by `pkgs.system`
    # inherit system;
    pkgs = pkgs' meta.system;

    modules = [
      # Main configuration
      "${root}/configuration.nix"
      # Home Manager
      (homeManagerModule args)
    ] ++ (builtins.attrValues config.flake.${configuration-type-to-outputs-modules "nix-on-droid"});

    extraSpecialArgs = {
      inherit inputs;
      inherit meta;
    };

    home-manager-path = inputs.home-manager.outPath;
  };

  mkNixDarwinHost = args @ { root, meta, users }: inputs.nix-darwin.lib.darwinSystem {
    inherit (meta) system;
    pkgs = pkgs' meta.system;

    modules = [
      # Main configuration
      "${root}/configuration.nix"
      # Home Manager
      inputs.home-manager.darwinModules.home-manager
      (homeManagerModule args)
      # # Set `nixpkgs.hostPlatform`
      # {
      #   nixpkgs.hostPlatform = system;
      # }
    ] ++ (builtins.attrValues config.flake.${configuration-type-to-outputs-modules "nix-darwin"});

    specialArgs = {
      inherit inputs;
      inherit meta;
    };
  };

  mkHomeManagerHost = args @ { root, meta }: inputs.home-manager.lib.homeManagerConfiguration {
    inherit (meta) system;
    pkgs = pkgs' meta.system;

    modules = [
      "${root}/home.nix"
    ] ++ (builtins.attrValues config.flake.${configuration-type-to-outputs-modules "home-manager"});

    extraSpecialArgs = {
      inherit inputs;
      inherit meta;
    };
  };
in
{
  options = let
    inherit (lib) types;
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
                    args @ { root, host, meta, configuration }:
                      inputs.deploy-rs.''${meta.system}.activate.nixos configuration;
                  '';
                };
                resultConfigurations = lib.mkOption {
                  description = ''
                    The resulting automatic configurations
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
                            meta = import meta-path;
                            deploy-config = meta.deploy or null;
                            has-mkDeployNode = mkDeployNode != null;
                            has-deploy-config = builtins.pathExists meta-path && deploy-config != null;
                            configuration-args = { inherit root host configurationFiles; };
                            valid = predicate configuration-args;
                            configuration = mkHost configuration-args;
                            deploy-args = { inherit root host meta configuration; };
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
              config = {};
            }));
            # TODO: put in a more visible place
            default = {
              nixos = {
                predicate = ({ root, host, configurationFiles, ... }: let
                  meta = import "${root}/meta.nix";
                in
                  and [
                    (! (host == "__template__"))
                    (hasFiles
                      [ "configuration.nix" "meta.nix" ]
                      configurationFiles)
                    (meta.enable or true)
                  ]);
                mkHost = ({ root, host, configurationFiles, ... }: let
                  meta = import "${root}/meta.nix" // {
                    hostname = host;
                  };
                in
                  mkNixosHost {
                    inherit root;
                    inherit meta;
                    users = genUsers configurationFiles;
                  });
                mkDeployNode = ({ root, host, meta, configuration }:
                  {
                    inherit (meta.deploy) hostname;
                    profiles.system = meta.deploy // {
                      path = inputs.deploy-rs.lib.${meta.system}.activate."nixos" configuration;
                    };
                  });
              };
              nix-on-droid = {
                predicate = ({ root, host, configurationFiles, ... }: let
                  meta = import "${root}/meta.nix";
                in
                  and [
                    (! (host == "__template__"))
                    (hasFiles
                      [ "configuration.nix" "home.nix" "meta.nix" ]
                      configurationFiles)
                    (meta.enable or true)
                  ]);
                mkHost = ({ root, host, configurationFiles, ... }: let
                  meta = import "${root}/meta.nix" // {
                    hostname = host;
                  };
                in
                  mkNixOnDroidHost {
                    inherit root;
                    inherit meta;
                  });
              };
              nix-darwin = {
                hostsName = "darwinHosts";
                configurationsName = "darwinConfigurations";
                predicate = ({ root, host, configurationFiles, ... }: let
                  meta = import "${root}/meta.nix";
                in
                  and [
                    (! (host == "__template__"))
                    (hasFiles
                      [ "configuration.nix" "meta.nix" ]
                      configurationFiles)
                    (hasDirectories
                      [ "home" ]
                      configurationFiles)
                    (meta.enable or true)
                  ]);
                mkHost = ({ root, host, configurationFiles, ... }: let
                  meta = import "${root}/meta.nix" // {
                    hostname = host;
                  };
                in
                  mkNixDarwinHost {
                    inherit root;
                    inherit meta;
                    users = genUsers configurationFiles;
                  });
                mkDeployNode = ({ root, host, meta, configuration }:
                  {
                    inherit (meta.deploy) hostname;
                    profiles.system = meta.deploy // {
                      path = inputs.deploy-rs.lib.${meta.system}.activate."darwin" configuration;
                    };
                  });
              };
              home-manager = {
                hostsName = "homeHosts";
                configurationsName = "homeConfigurations";
                predicate = ({ root, host, configurationFiles, ... }: let
                  meta = import "${root}/meta.nix";
                in
                  and [
                    (! (host == "__template__"))
                    (hasFiles
                      [ "home.nix" "meta.nix" ]
                      configurationFiles)
                    (meta.enable or true)
                  ]);
                mkHost = ({ root, host, configurationFiles, ... }: let
                  meta = import "${root}/meta.nix" // {
                    hostname = host;
                  };
                in
                  mkHomeManagerHost {
                    inherit root;
                    inherit meta;
                  });
              };
            };
          };
          resultConfigurations = lib.mkOption {
            readOnly = true;
            default = lib.pipe configurationTypes [
              (lib.mapAttrs'
                (configurationType: configurationTypeConfig:
                  lib.nameValuePair
                    configurationTypeConfig.configurationsName
                    (lib.mapAttrs
                      (host: { configuration, ... }:
                        configuration)
                      configurationTypeConfig.resultConfigurations)))
            ];
          };
          resultDeployNodes = lib.mkOption {
            readOnly = true;
            default = lib.pipe configurationTypes [
              (lib.concatMapAttrs
                (configurationType: configurationTypeConfig:
                  (lib.concatMapAttrs
                    (host: { deploy ? null, ... }:
                      lib.optionalAttrs
                        (deploy != null)
                        {
                          ${host} = deploy;
                        })
                    configurationTypeConfig.resultConfigurations)))
            ];
          };
        };
      });
      default = {};
    };
  };

  config = {
    flake = let
      configurations = config.auto.configurations.resultConfigurations;
      deployNodes = {
        deploy.nodes = config.auto.configurations.resultDeployNodes;
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
