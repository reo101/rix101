# Build generated configuration and its referenced init snippets, not an activation package.
let
  flake = builtins.getFlake (toString ../../../..);
  system = flake.nixosConfigurations.rungen;
  pkgs = system.pkgs;
  lib = pkgs.lib;
  configuration = system.config.home-manager.users.reo101;
  files = {
    "zshrc" = configuration.home.file.".config/zsh/.zshrc".source;
    "config.nu" =
      configuration.home.file."${configuration.programs.nushell.configDir}/config.nu".source;
    "env.nu" = configuration.home.file."${configuration.programs.nushell.configDir}/env.nu".source;
    "atuin.toml" = configuration.home.file."${configuration.xdg.configHome}/atuin/config.toml".source;
    "starship.toml" = configuration.home.file.${configuration.programs.starship.configPath}.source;
  };
  manifest = {
    homeDirectory = configuration.home.homeDirectory;
    binaries = {
      zsh = lib.getExe configuration.programs.zsh.package;
      nushell = lib.getExe configuration.programs.nushell.package;
      starship = lib.getExe configuration.programs.starship.package;
      jujutsu = lib.getExe pkgs.jujutsu;
      carapace = lib.getExe configuration.programs.carapace.finalPackage;
      atuin = lib.getExe configuration.programs.atuin.package;
      direnv = lib.getExe configuration.programs.direnv.package;
      zoxide = lib.getExe configuration.programs.zoxide.package;
    };
    plugins = builtins.map (plugin: {
      inherit (plugin) name;
      source = toString plugin.src;
    }) configuration.programs.zsh.plugins;
  };
in
pkgs.linkFarm "rix101-shell-generated-regression" (
  lib.mapAttrsToList (name: path: { inherit name path; }) files
  ++ [
    {
      name = "manifest.json";
      path = pkgs.writeText "rix101-shell-regression-manifest.json" (builtins.toJSON manifest);
    }
  ]
)
