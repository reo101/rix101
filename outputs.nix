inputs:
inputs.flake-parts.lib.mkFlake { inherit inputs; } (
  { withSystem, flake-parts-lib, ... }:
  {
    systems = import inputs.systems.outPath;

    # BUG: infinite recursion
    # imports = [
    #   ./modules/flake/modules
    # ] ++ inputs.self.flakeModules;

    imports = [
      ./modules/flake/flake-file.nix
      ./modules/flake/lib
      ./modules/flake/lib-custom
      ./modules/flake/pkgs
      ./modules/flake/modules
      ./modules/flake/roles
      ./modules/flake/configurations
      ./modules/flake/agenix
      ./modules/flake/topology
      ./modules/flake/packages
      ./modules/flake/overlays
      ./modules/flake/shells
      ./modules/flake/templates
    ];

    auto = {
      # Automatic modules, see `./modules/flake/modules/default.nix`
      modules.enableAll = true;

      # Automatic roles, see `./modules/flake/roles/default.nix`
      roles.enable = true;

      # Automatic configurations, see `./modules/flake/configurations/default.nix`
      configurations.enableAll = true;

      # Automatic packages, see `./modules/flake/packages/default.nix`
      packages.enable = true;

      # Automatic overlays, see `./modules/flake/overlays/default.nix`
      overlays.enable = true;

      # Automatic devShells, see `./modules/flake/shells/default.nix`
      devShells.enable = true;

      # Automatic templates, see `./modules/flake/templates/default.nix`
      templates.enable = true;
    };

    perSystem =
      { pkgs, ... }:
      {
        # Apps (`nix run`)
        apps = import ./apps { inherit pkgs; };

        # Formatter (`nix fmt`)
        formatter = pkgs.nixfmt;
      };

    flake = {
      inherit (inputs) self;
    };
  }
)
