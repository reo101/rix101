{ lib, config, self, inputs, withSystem, ... }:

let
  outputs = self;
  inherit (import ../../nix/utils.nix { inherit lib self; })
    and
    hasFiles
    hasDirectories
    recurseDir
    configuration-type-to-outputs-modules
    configuration-type-to-outputs-machines;
in
let
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
        inherit inputs outputs;
        # TODO: meta?
        inherit hostname;
      };
    } // (if users == null then {
      # nixOnDroid
      config = "${root}/home.nix";
    } else {
      # Not nixOnDroid
      users = lib.attrsets.genAttrs
        users
          (user: import "${root}/home/${user}.nix");
    });
  };

  # Configuration helpers
  configurationTypes = ["nixos" "nix-on-droid" "nix-darwin" "home-manager"];

  mkNixosHost = args @ { root, system, hostname, users }: lib.nixosSystem {
    inherit system;
    pkgs = withSystem system ({ pkgs, ... }: pkgs);

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
      inherit inputs outputs;
    };
  };

  mkNixOnDroidHost = args @ { root, system, hostname }: inputs.nix-on-droid.lib.nixOnDroidConfiguration {
    # NOTE: inferred by `pkgs.system`
    # inherit system;
    pkgs = withSystem system ({ pkgs, ... }: pkgs);

    modules = [
      # Main configuration
      "${root}/configuration.nix"
      # Home Manager
      (homeManagerModule args)
    ] ++ (builtins.attrValues config.flake.${configuration-type-to-outputs-modules "nix-on-droid"});

    extraSpecialArgs = {
      inherit inputs outputs;
    };

    home-manager-path = inputs.home-manager.outPath;
  };

  mkNixDarwinHost = args @ { root, system, hostname, users }: inputs.nix-darwin.lib.darwinSystem {
    inherit system;
    pkgs = withSystem system ({ pkgs, ... }: pkgs);

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
      inherit inputs outputs;
    };
  };

  mkHomeManagerHost = args @ { root, system, hostname }: inputs.home-manager.lib.homeManagerConfiguration {
    inherit system;
    pkgs = withSystem system ({ pkgs, ... }: pkgs);

    modules = [
      "${root}/home.nix"
    ] ++ (builtins.attrValues config.flake.${configuration-type-to-outputs-modules "home-manager"});

    extraSpecialArgs = {
      inherit inputs outputs;
      inherit hostname;
    };
  };

  createConfigurations =
    pred: mkHost: machines:
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
          machines));
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
            default = "${self}/machines";
            defaultText = ''''${self}/machines'';
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
    flake = let
      autoMachines =
        lib.pipe
          configurationTypes
          [
            (builtins.map
              (configurationType:
                lib.nameValuePair
                "${configuration-type-to-outputs-machines configurationType}"
                (if config.flake.autoConfigurations.${configurationType}.enable
                  then recurseDir config.flake.autoConfigurations.${configurationType}.dir
                  else { })))
            builtins.listToAttrs
          ];
    in {
      # Machines
      # NOTE: manually inheriting generated machines to avoid recursion
      #       (`autoMachines` depends on `config.flake` itself)
      inherit (autoMachines)
        nixosMachines
        darwinMachines
        nixOnDroidMachines
        homeManagerMachines;

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
          config.flake.${configuration-type-to-outputs-machines "nixos"};

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
          config.flake.${configuration-type-to-outputs-machines "nix-on-droid"};

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
          config.flake.${configuration-type-to-outputs-machines "nix-darwin"};

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
              root = "${config.flake.homeManager.home-manager.dir}/${system}/${host}";
              inherit system;
              hostname = host;
            })
          config.flake.${configuration-type-to-outputs-machines "home-manager"};
    };
  };
}
