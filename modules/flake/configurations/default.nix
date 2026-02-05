{ lib, config, self, inputs, withSystem, ... }:

{
  key = "rix101.modules.flake.configurations";

  config.flake-file.inputs = {
    # Home Manager
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Nix on Droid
    nix-on-droid = {
      url = "github:t184256/nix-on-droid";
      # url = "github:t184256/nix-on-droid/master";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
    dnshack = {
      url = "github:ettom/dnshack";
      flake = false;
    };

    # Nix Darwin
    nix-darwin = {
      url = "github:lnl7/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    mac-app-util = {
      url = "github:hraban/mac-app-util";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.systems.follows = "systems";
      # WARN: needs `nix` `2.30`+
      inputs.cl-nix-lite.inputs.systems.follows = "systems";
      inputs.cl-nix-lite.inputs.nixpkgs.follows = "nixpkgs";
      inputs.cl-nix-lite.inputs.flake-parts.follows = "flake-parts";
      inputs.cl-nix-lite.inputs.treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.inputs.systems.follows = "systems";
    };

    deploy-rs = {
      url = "github:serokell/deploy-rs";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.utils.inputs.systems.follows = "systems";
    };

    openwrt-imagebuilder = {
      url = "github:astro/nix-openwrt-imagebuilder";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
      inputs.systems.follows = "systems";
    };
  };

  imports = [
    ../lib
    ../lib-custom
    ./default-generators.nix
  ];

  options = let
    inherit (lib)
      types
      ;
    inherit (config.lib.custom)
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
            defaultText = ''${self}/hosts'';
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
                    Name(s) for the configurations output.
                    Can be a string (used as `old`, with `new = null`) or an attrset with `old` and/or `new`.
                    - `old`: Name for the `''${configurationType}Configurations` output (null to skip)
                    - `new`: Name for the `configurations.''${configurationType}` output (null to skip)
                  '';
                  type = types.either types.str (types.submodule {
                    options = {
                      old = lib.mkOption {
                        type = types.nullOr types.str;
                        default = null;
                      };
                      new = lib.mkOption {
                        type = types.nullOr types.str;
                        default = null;
                      };
                    };
                  });
                  default = { old = "${kebabToCamel name}Configurations"; new = name; };
                  apply = v: if builtins.isString v then { old = v; new = null; } else v;
                };
                predicate = lib.mkOption {
                  description = ''
                    Function for filtering configurations
                  '';
                  type = types.functionTo types.anything;
                  apply = f: args: lib.pipe args [
                    (config.lib.contracts.is config.lib.custom.recurseDirContracts.ConfigurationArgs)
                    f
                    (config.lib.contracts.is config.lib.contracts.Bool)
                  ];
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
                      ] ++ (lib.attrValues config.flake.nixosModules);

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
                  type = types.attrsOf (types.attrsOf types.unspecified) // {
                    # Custom merge to avoid the module system trying to interpret
                    # attributes from nixosSystem results (e.g. `passthru`) as options.
                    # Without this, the module system's default merge would attempt to
                    # recursively evaluate all attributes as if they were module options,
                    # causing "passthru was accessed but has no value defined" errors.
                    merge = loc: defs:
                      lib.foldl' (acc: def: lib.recursiveUpdate acc def.value) {} defs;
                  };
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
                                # Give access to overlayed `lib`
                                inherit (config) lib;
                                # Pass through host (default for `hostname`, etc.)
                                inherit host;
                              };
                              modules = [
                                # {} if no `metaModule` is provided
                                metaModule
                                # {} if no `meta.nix` is provided
                                (if has-meta then { _file = meta-file.path; imports = [ meta-content ]; } else {})
                              ];
                            }).config;
                            deploy-config = meta.deploy or null;
                            has-deploy-config = deploy-config != null;
                            has-mkDeployNode = mkDeployNode != null;
                            configuration-args = config.lib.contracts.is config.lib.custom.recurseDirContracts.ConfigurationArgs { inherit meta configurationFiles; };
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
              configurations = let
                mkResultConfigurations = new: lib.pipe configurationTypes ([
                  (lib.concatMapAttrs
                    (_configurationType: configurationTypeConfig:
                      let name = configurationTypeConfig.configurationsName.${if new then "new" else "old"};
                      in lib.optionalAttrs (name != null) {
                        ${name} =
                          lib.mapAttrs
                            (_host: { configuration, meta, ... }:
                              configuration // {
                                # NOTE: for introspection
                                inherit meta;
                              })
                            configurationTypeConfig.result;
                      }))
                 ] ++ lib.optional new (configurations: { inherit configurations; }));
              in {
                # NOTE: old:  ${name}Configurations.${configuration}
                #       new: configurations.${name}.${configuration}
                old = mkResultConfigurations false;
                new = mkResultConfigurations true;
              };
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
      configurationsOld = config.auto.configurations.result.configurations.old;
      configurationsNew = config.auto.configurations.result.configurations.new;
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
    in configurationsOld // configurationsNew // deployNodes // deployChecks;
  };
}
