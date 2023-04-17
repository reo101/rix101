{ inputs, outputs, ... }:

let
  inherit (inputs) nixpkgs;
  inherit (nixpkgs) lib;
  inherit (lib) mapAttrs;
  inherit (lib.attrsets) filterAttrs;
in
rec {
  # Directory walker
  recurseDir = dir:
    mapAttrs
      (file: type:
        if type == "directory"
        then recurseDir "${dir}/${file}"
        else type
      )
      (builtins.readDir dir);

  # NOTE: Implying `attrs` is the output of `recurseDir`
  hasFiles = files: attrs:
    builtins.all
      (b: b)
      (builtins.map
        (file:
          builtins.hasAttr file attrs &&
          builtins.getAttr file attrs == "regular")
        files);

  # NOTE: Implying `attrs` is the output of `recurseDir`
  hasDirectories = directories: attrs:
    builtins.all
      (b: b)
      (builtins.map
        (directory:
          builtins.hasAttr directory attrs &&
          builtins.getAttr directory attrs == "set")
        directories);

  # pkgs helpers
  forEachSystem = lib.genAttrs [
    "aarch64-linux"
    "i686-linux"
    "x86_64-linux"
    "aarch64-darwin"
    "x86_64-darwin"
  ];

  forEachPkgs = f:
    forEachSystem
      (system:
        f nixpkgs.legacyPackages.${system});

  # Modules
  nixosModules = import ../modules/nixos;
  nixOnDroidModules = import ../modules/nix-on-droid;
  nixDarwinModules = import ../modules/nix-darwin;
  homeManagerModules = import ../modules/home-manager;

  # Machines
  machines = recurseDir ../machines;
  homeManagerMachines = machines.home-manager or { };
  nixDarwinMachines = machines.nix-darwin or { };
  nixOnDroidMachines = machines.nix-on-droid or { };
  nixosMachines = machines.nixos or { };

  # Configuration helpers
  mkNixosHost = root: system: hostname: users: lib.nixosSystem {
    inherit system;

    modules = [
      (root + "/configuration.nix")
      inputs.home-manager.nixosModules.home-manager
      inputs.nur.nixosModules.nur
      {
        home-manager = {
          useGlobalPkgs = false;
          useUserPackages = true;
          users = lib.attrsets.genAttrs
            users
            (user: import (root + "/home/${user}.nix"));
          sharedModules = builtins.attrValues homeManagerModules;
          extraSpecialArgs = {
            inherit inputs outputs;
          };
        };
      }
    ] ++ (builtins.attrValues nixosModules);

    specialArgs = {
      inherit inputs outputs;
    };
  };

  mkNixOnDroidHost = root: system: hostname: inputs.nix-on-droid.lib.nixOnDroidConfiguration {
    pkgs = import nixpkgs {
      inherit system;

      overlays = [
        inputs.nix-on-droid.overlays.default
      ];
    };

    modules = [
      (root + "/configuration.nix")
      { nix.registry.nixpkgs.flake = nixpkgs; }
      {
        home-manager = {
          config = (root + "/home.nix");
          backupFileExtension = "hm-bak";
          useGlobalPkgs = false;
          useUserPackages = true;
          sharedModules = builtins.attrValues homeManagerModules;
          extraSpecialArgs = { inherit inputs; };
        };
      }
    ] ++ (builtins.attrValues nixOnDroidModules);

    extraSpecialArgs = {
      inherit inputs outputs;
      # rootPath = ./.;
    };

    home-manager-path = inputs.home-manager.outPath;
  };

  mkNixDarwinHost = root: system: hostname: users: inputs.nix-darwin.lib.darwinSystem {
    inherit system;

    modules = [
      (root + "/configuration.nix")
      inputs.home-manager.darwinModules.home-manager
      {
        home-manager = {
          useGlobalPkgs = false;
          useUserPackages = true;
          users = lib.attrsets.genAttrs
            users
            (user: import (root + "/home/${user}.nix"));
          sharedModules = builtins.attrValues homeManagerModules;
          extraSpecialArgs = { inherit inputs outputs; };
        };
      }
    ] ++ (builtins.attrValues nixDarwinModules);

    inputs = { inherit inputs outputs nixpkgs; };
  };

  mkHomeManagerHost = root: system: hostname: inputs.home-manager.lib.homeManagerConfiguration {
    pkgs = nixpkgs.legacyPackages.${system};

    modules = [
      (root + "/home.nix")
    ] ++ (builtins.attrValues homeManagerModules);

    extraSpecialArgs = { inherit inputs outputs; };
  };

  createConfigurations =
    pred: mkHost: machines:
    lib.foldAttrs
      (acc: x: acc)
      [ ]
      (builtins.attrValues
        (builtins.mapAttrs
          (system: hosts:
          lib.attrsets.filterAttrs
            (host: config: config != null)
            (builtins.mapAttrs
              (host: config:
              if (pred system host config)
              then mkHost system host config
              else null)
              hosts))
          machines));

  # Configurations
  autoNixosConfigurations =
    createConfigurations
      (system: host: config:
        hasFiles
          [ "configuration.nix" ]
          config)
      (system: host: config:
        mkNixosHost
          ../machines/nixos/${system}/${host}
          system
          host
          (builtins.map
            (lib.strings.removeSuffix ".nix")
            (builtins.attrNames (config."home" or { }))))
      nixosMachines;

  autoNixOnDroidConfigurations =
    createConfigurations
      (system: host: config:
        hasFiles
          [ "configuration.nix" "home.nix" ]
          config)
      (system: host: config:
        mkNixOnDroidHost
          ../machines/nix-on-droid/${system}/${host}
          system
          host)
      nixOnDroidMachines;

  autoDarwinConfigurations =
    createConfigurations
      (system: host: config:
        hasFiles
          [ "configuration.nix" ]
          config)
      (system: host: config:
        mkNixDarwinHost
          ../machines/nix-darwin/${system}/${host}
          system
          host
          (builtins.map
            (lib.strings.removeSuffix ".nix")
            (builtins.attrNames (config."home" or { }))))
      nixDarwinMachines;

  autoHomeConfigurations =
    createConfigurations
      (system: host: config:
        hasFiles
          [ "home.nix" ]
          config)
      (system: host: config:
        mkHomeManagerHost
          ../machines/home-manager/${system}/${host}
          system
          host)
      homeManagerMachines;
}
