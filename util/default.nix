{ inputs, outputs, ... }:

let
  inherit (inputs) nixpkgs;
  inherit (nixpkgs) lib;
in
rec {
  # Boolean helpers
  and = lib.all lib.id;
  or = lib.any lib.id;
  eq = x: y: x == y;

  # Directory walking helpers
  recurseDir = dir:
    lib.mapAttrs
      (file: type:
        if type == "directory"
        then recurseDir "${dir}/${file}"
        else type)
      (builtins.readDir dir);

  allSatisfy = predicate: attrs: attrset:
    lib.all
      (attr:
         and [
           (builtins.hasAttr attr attrset)
           (predicate (builtins.getAttr attr attrset))
         ])
      attrs;

  # NOTE: Implying last argument is the output of `recurseDir`
  hasFiles = allSatisfy (eq "regular");

  # NOTE: Implying last argument is the output of `recurseDir`
  hasDirectories = allSatisfy lib.isAttrs;

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

  # Modules helpers
  createModules = baseDir: { passthru ? { inherit inputs outputs; }, ... }:
    lib.pipe baseDir [
      # Read given directory
      builtins.readDir
      # Map each entry to a module
      (lib.mapAttrs'
        (name: type:
          let
            moduleDir = lib.path.append baseDir "${name}";
          in
          if and [
            (type == "directory")
            (hasFiles [ "default.nix" ] (builtins.readDir moduleDir))
          ] then
            # Classic module in a directory
            lib.nameValuePair
              name
              (import moduleDir)
          else if and [
            (type == "regular")
            (lib.hasSuffix ".nix" name)
          ] then
            # Classic module in a file
            lib.nameValuePair
              (lib.removeSuffix ".nix" name)
              (import moduleDir)
          else
            # Invalid module
            lib.nameValuePair
              name
              null))
      # Filter invalid modules
      (lib.filterAttrs
        (moduleName: module:
          module != null))
      # Passthru if needed
      (lib.mapAttrs
        (moduleName: module:
          if and [
            (builtins.isFunction
              module)
            (eq
              (lib.pipe module [ builtins.functionArgs builtins.attrNames ])
              (lib.pipe passthru [ builtins.attrNames ]))
          ]
          then module passthru
          else module))
    ];

  # Modules
  nixosModules       = createModules ../modules/nixos        { };
  nixOnDroidModules  = createModules ../modules/nix-on-droid { };
  nixDarwinModules   = createModules ../modules/nix-darwin   { };
  homeManagerModules = createModules ../modules/home-manager { };

  # Machines
  machines            = recurseDir ../machines;
  homeManagerMachines = machines.home-manager or { };
  nixDarwinMachines   = machines.nix-darwin   or { };
  nixOnDroidMachines  = machines.nix-on-droid or { };
  nixosMachines       = machines.nixos        or { };

  # Configuration helpers
  mkNixosHost = root: system: hostname: users: lib.nixosSystem {
    inherit system;

    modules = [
      (lib.path.append root "configuration.nix")
      inputs.home-manager.nixosModules.home-manager
      {
        home-manager = {
          useGlobalPkgs = false;
          useUserPackages = true;
          users = lib.attrsets.genAttrs
            users
            (user: import (lib.path.append root "home/${user}.nix"));
          sharedModules = builtins.attrValues homeManagerModules;
          extraSpecialArgs = {
            inherit inputs outputs;
            inherit hostname;
          };
        };
      }
      {
        networking.hostName = lib.mkDefault hostname;
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
      (lib.path.append root "configuration.nix")
      { nix.registry.nixpkgs.flake = nixpkgs; }
      {
        home-manager = {
          config = (lib.path.append root "home.nix");
          backupFileExtension = "hm-bak";
          useGlobalPkgs = false;
          useUserPackages = true;
          sharedModules = builtins.attrValues homeManagerModules;
          extraSpecialArgs = {
            inherit inputs outputs;
            inherit hostname;
          };
        };
      }
    ] ++ (builtins.attrValues nixOnDroidModules);

    extraSpecialArgs = {
      inherit inputs outputs;
      inherit hostname;
      # rootPath = ./.;
    };

    home-manager-path = inputs.home-manager.outPath;
  };

  mkNixDarwinHost = root: system: hostname: users: inputs.nix-darwin.lib.darwinSystem {
    inherit system;

    modules = [
      (lib.path.append root "configuration.nix")
      inputs.home-manager.darwinModules.home-manager
      {
        home-manager = {
          useGlobalPkgs = false;
          useUserPackages = true;
          users = lib.attrsets.genAttrs
            users
            (user: import (lib.path.append root "home/${user}.nix"));
          sharedModules = builtins.attrValues homeManagerModules;
          extraSpecialArgs = {
            inherit inputs outputs;
            inherit hostname;
          };
        };
      }
    ] ++ (builtins.attrValues nixDarwinModules);

    inputs = {
      inherit inputs outputs;
      inherit nixpkgs;
    };
  };

  mkHomeManagerHost = root: system: hostname: inputs.home-manager.lib.homeManagerConfiguration {
    pkgs = nixpkgs.legacyPackages.${system};

    modules = [
      (lib.path.append root "home.nix")
    ] ++ (builtins.attrValues homeManagerModules);

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
              (host: config:
                lib.optionalAttrs
                  (and [
                    (host != "__template__")
                    (pred system host config)
                  ])
                  {
                    ${host} = mkHost system host config;
                  })
              hosts)
          machines));

  # Configurations
  autoNixosConfigurations =
    createConfigurations
      (system: host: config:
        and
          [
            (hasFiles
              [ "configuration.nix" ]
              config)
            # (hasDirectories
            #   [ "home" ]
            #   config)
          ])
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
        and
          [
            (hasFiles
              [ "configuration.nix" "home.nix" ]
              config)
          ])
      (system: host: config:
        mkNixOnDroidHost
          ../machines/nix-on-droid/${system}/${host}
          system
          host)
      nixOnDroidMachines;

  autoDarwinConfigurations =
    createConfigurations
      (system: host: config:
        and
          [
            (hasFiles
              [ "configuration.nix" ]
              config)
            (hasDirectories
              [ "home" ]
              config)
          ])
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
        and
          [
            (hasFiles
              [ "home.nix" ]
              config)
          ])
      (system: host: config:
        mkHomeManagerHost
          ../machines/home-manager/${system}/${host}
          system
          host)
      homeManagerMachines;

  # Automatic deploy.rs nodes (for NixOS and nix-darwin)

  gen-config-type-to = mappings: mkError: config-type:
    mappings.${config-type} or
      (builtins.throw
        (mkError config-type));

  config-type-to-outputs-machines =
    gen-config-type-to
      {
        nixos = "nixosMachines";
        nix-on-droid = "nixOnDroidMachines";
        nix-darwin = "nixDarwinMachines";
        home-manager = "homeMachines";
      }
      (config-type:
        builtins.throw
          "Invaild config-type \"${config-type}\" for flake outputs' machines");

  config-type-to-outputs-configurations =
    gen-config-type-to
      {
        nixos = "nixosConfigurations";
        nix-on-droid = "nixOnDroidConfigurations";
        nix-darwin = "darwinConfigurations";
        home-manager = "homeConfigurations";
      }
      (config-type:
        builtins.throw
          "Invaild config-type \"${config-type}\" for flake outputs' configurations");

  config-type-to-deploy-type =
    gen-config-type-to
      {
        nixos = "nixos";
        nix-darwin = "darwin";
      }
      (config-type:
        builtins.throw
          "Invaild config-type \"${config-type}\" for deploy-rs deployment");

  deploy.autoNodes =
    lib.flip lib.concatMapAttrs
      (lib.genAttrs
        [
          "nixos"
          "nix-darwin"
        ]
        (config-type:
          let
            machines = config-type-to-outputs-machines config-type;
          in
            outputs.${machines}))
      (config-type: machines:
        lib.pipe
          machines
          [
            # Filter out nondirectories
            (lib.filterAttrs
              (system: configs:
                builtins.isAttrs configs))
            # Convert non-template configs into `system-and-config` pairs
            (lib.concatMapAttrs
              (system: configs:
                (lib.concatMapAttrs
                  (host: config:
                    lib.optionalAttrs
                      (host != "__template__")
                      {
                        ${host} = {
                          inherit system;
                          config =
                            let
                              configurations = config-type-to-outputs-configurations config-type;
                            in
                              outputs.${configurations}.${host};
                        };
                      })
                  configs)))
            # Convert each `system-and-config` pair into a deploy-rs node
            (lib.concatMapAttrs
              (host: { system, config }:
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
                  }))
          ]);

  autoChecks =
    lib.mapAttrs
      (system: deployLib:
        deployLib.deployChecks
          outputs.deploy)
      inputs.deploy-rs.lib;
}
