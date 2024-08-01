{ lib, config, self, inputs, withSystem, ... }:

let
  inherit (config.lib)
    and
    hasFiles
    hasDirectories
    recurseDir
    configuration-type-to-outputs-modules;
in
let
  # Configuration helpers
  configurationTypes = ["nixos" "nix-on-droid" "nix-darwin" "home-manager"];

  # `pkgs` with flake's overlays
  # NOTE: done here to avoid infinite recursion
  pkgs' = system:
    (withSystem system ({ pkgs, ... }: pkgs)).extend
      (final: prev: inputs.self.packages.${system});

  homeManagerModule = { root, system, hostname, users ? null }: {
    home-manager = {
      # Use same `pkgs` instance as system (i.e. carry over overlays)
      useGlobalPkgs = true;
      # Do not keep packages in ${HOME}
      useUserPackages = true;
      # Default import all of our exported `home-manager` modules
      sharedModules = builtins.attrValues config.flake.${configuration-type-to-outputs-modules "home-manager"};
      # Pass in `inputs`, `outputs` and maybe `meta`
      extraSpecialArgs = {
        inherit inputs;
        # TODO: meta?
        inherit hostname;
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

  mkNixosHost = args @ { root, system, hostname, users }: inputs.nixpkgs.lib.nixosSystem {
    inherit system;
    pkgs = pkgs' system;

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
        networking.hostName = lib.mkDefault hostname;
      }
    ] ++ (builtins.attrValues config.flake.${configuration-type-to-outputs-modules "nixos"});

    specialArgs = {
      inherit inputs;
    };
  };

  mkNixOnDroidHost = args @ { root, system, hostname }: inputs.nix-on-droid.lib.nixOnDroidConfiguration {
    # NOTE: inferred by `pkgs.system`
    # inherit system;
    pkgs = pkgs' system;

    modules = [
      # Main configuration
      "${root}/configuration.nix"
      # Home Manager
      (homeManagerModule args)
    ] ++ (builtins.attrValues config.flake.${configuration-type-to-outputs-modules "nix-on-droid"});

    extraSpecialArgs = {
      inherit inputs;
    };

    home-manager-path = inputs.home-manager.outPath;
  };

  mkNixDarwinHost = args @ { root, system, hostname, users }: inputs.nix-darwin.lib.darwinSystem {
    inherit system;
    pkgs = pkgs' system;

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
    };
  };

  mkHomeManagerHost = args @ { root, system, hostname }: inputs.home-manager.lib.homeManagerConfiguration {
    inherit system;
    pkgs = pkgs' system;

    modules = [
      "${root}/home.nix"
    ] ++ (builtins.attrValues config.flake.${configuration-type-to-outputs-modules "home-manager"});

    extraSpecialArgs = {
      inherit inputs;
      inherit hostname;
    };
  };

  createConfigurations =
    pred: mkHost: hosts:
    lib.foldAttrs
      lib.const
      [ ]
      (builtins.attrValues
        (builtins.mapAttrs
          (system: hosts:
            lib.concatMapAttrs
              (host: configurationFiles:
                lib.optionalAttrs
                  (and [
                    (host != "__template__")
                    (pred { inherit system host configurationFiles; })
                  ])
                  {
                    ${host} = mkHost { inherit system host configurationFiles; };
                  })
              hosts)
          hosts));
in
{
  options = let
    inherit (lib) types;
  in {
    flake.autoConfigurations = lib.mkOption {
      description = ''
        Automagically generate configurations from walking directories with Nix files
      '';
      type = types.submodule (submodule: {
        options = {
          enableAll = lib.mkEnableOption "Automatic ${builtins.toString configurationTypes} configurations extraction";
          baseDir = lib.mkOption {
            description = ''
              Base directory of the contained configurations, used as a base for the rest of the options
            '';
            type = types.path;
            default = "${self}/hosts";
            defaultText = ''''${self}/hosts'';
          };
        } // (
          lib.pipe
          configurationTypes
          [
            (builtins.map
              # NOTE: create small submodule for every `configurationType`
              (configurationType:
                lib.nameValuePair
                "${configurationType}"
                (lib.mkOption {
                  type = types.submodule {
                    options = {
                      # NOTE: each can be enabled (default global `enableAll`)
                      enable = lib.mkEnableOption "Automatic ${configurationType} configurations extraction" // {
                        default = submodule.config.enableAll;
                      };
                      # NOTE: each can be read from a different directory
                      # (default global `baseDir` + `camelToKebab`-ed `configurationType`)
                      dir = lib.mkOption {
                        type = types.path;
                        default = "${submodule.config.baseDir}/${configurationType}";
                      };
                      # TODO: split hosts and configurations?
                      resultHosts = lib.mkOption {
                        description = ''
                          The resulting automatic packages
                        '';
                        # TODO: specify
                        type = types.unspecified;
                        readOnly = true;
                        internal = true;
                        default =
                          lib.optionalAttrs
                            config.flake.autoConfigurations.${configurationType}.enable
                            (recurseDir config.flake.autoConfigurations.${configurationType}.dir);
                      };
                    };
                  };
                  default = {};
                })))
            builtins.listToAttrs
          ]);
      });
      default = {};
    };
  };

  config = {
    flake = {
      # Configurations
      nixosConfigurations =
        createConfigurations
          ({ system, host, configurationFiles, ... }:
            and
              [
                (hasFiles
                  [ "configuration.nix" ]
                  configurationFiles)
                # (hasDirectories
                #   [ "home" ]
                #   config)
              ])
          ({ system, host, configurationFiles, ... }:
            mkNixosHost {
              root = "${config.flake.autoConfigurations.nixos.dir}/${system}/${host}";
              inherit system;
              hostname = host;
              users = (builtins.map
                (lib.strings.removeSuffix ".nix")
                (builtins.attrNames (configurationFiles."home" or { })));
            })
          config.flake.autoConfigurations.nixos.resultHosts;

      nixOnDroidConfigurations =
        createConfigurations
          ({ system, host, configurationFiles, ... }:
            and
              [
                (hasFiles
                  [ "configuration.nix" "home.nix" ]
                  configurationFiles)
              ])
          ({ system, host, configurationFiles, ... }:
            mkNixOnDroidHost {
              root = "${config.flake.autoConfigurations.nix-on-droid.dir}/${system}/${host}";
              inherit system;
              hostname = host;
            })
          config.flake.autoConfigurations.nix-on-droid.resultHosts;

      darwinConfigurations =
        createConfigurations
          ({ system, host, configurationFiles, ... }:
            and
              [
                (hasFiles
                  [ "configuration.nix" ]
                  configurationFiles)
                (hasDirectories
                  [ "home" ]
                  configurationFiles)
              ])
          ({ system, host, configurationFiles, ... }:
            mkNixDarwinHost {
              root = "${config.flake.autoConfigurations.nix-darwin.dir}/${system}/${host}";
              inherit system;
              hostname = host;
              users = (builtins.map
                (lib.strings.removeSuffix ".nix")
                (builtins.attrNames (configurationFiles."home" or { })));
            })
          config.flake.autoConfigurations.nix-darwin.resultHosts;

      homeConfigurations =
        createConfigurations
          ({ system, host, configurationFiles, ... }:
            and
              [
                (hasFiles
                  [ "home.nix" ]
                  configurationFiles)
              ])
          ({ system, host, configurationFiles, ... }:
            mkHomeManagerHost {
              root = "${config.flake.autoConfigurations.home-manager.dir}/${system}/${host}";
              inherit system;
              hostname = host;
            })
          config.flake.autoConfigurations.home-manager.resultHosts;
    };
  };
}
