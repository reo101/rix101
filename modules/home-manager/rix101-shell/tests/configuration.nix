# nix eval --impure --json --file modules/home-manager/rix101-shell/tests/configuration.nix
let
  flake = builtins.getFlake (toString ../../../..);
  pkgs = flake.nixosConfigurations.rungen.pkgs;
  lib = pkgs.lib;
  configuration =
    metadata: overrides:
    (flake.inputs.home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      extraSpecialArgs = lib.optionalAttrs (metadata != null) { meta = metadata; };
      modules = [
        ../default.nix
        {
          home.username = "shell-regression";
          home.homeDirectory = "/tmp/rix101-shell-regression-home";
          home.stateVersion = "26.05";
          rix101.shell.enable = true;
        }
        overrides
      ];
    }).config;
  metadata = {
    hostname = "fixture";
    configurationType = "home-manager";
    gui = false;
  };
  configured = configuration metadata { rix101.shell.gpg.enable = true; };
  overridden = configuration metadata {
    rix101.shell.rebuildBackend = "nix-darwin";
    rix101.shell.rebuildTarget = "custom-target";
    rix101.shell.flakePath = "/tmp/flake reference with 'quotes'";
  };
  emptyShells = builtins.tryEval (
    builtins.deepSeq ((configuration metadata { rix101.shell.shells = [ ]; }).rix101.shell.shells) true
  );
  externallyEnabledAgent = configuration metadata { services.gpg-agent.enable = true; };
  withoutMetadata = configuration null { };
  externalNushell = configuration metadata {
    rix101.shell.shells = [ "zsh" ];
    programs.nushell.enable = true;
    services.gpg-agent.enable = true;
  };
  disabled = configuration metadata { rix101.shell.enable = lib.mkForce false; };
  arm = flake.nixosConfigurations.cheetah-avf.config.home-manager.users.reo101;
  identity = configuration: {
    inherit (configuration.rix101.shell) rebuildBackend rebuildTarget;
  };
in
assert configured.rix101.shell.rebuildTarget == metadata.hostname;
assert configured.rix101.shell.rebuildBackend == "home-manager";
assert withoutMetadata.rix101.shell.rebuildBackend == "home-manager";
assert withoutMetadata.rix101.shell.rebuildTarget == null;
assert overridden.rix101.shell.rebuildTarget == "custom-target";
assert overridden.rix101.shell.rebuildBackend == "nix-darwin";
assert !emptyShells.success;
assert !disabled.programs.zsh.enable && !disabled.programs.nushell.enable;
assert configured.programs.atuin.enable && configured.programs.atuin.enableNushellIntegration;
assert !configured.programs.atuin.enableZshIntegration;
assert configured.programs.carapace.environment.CARAPACE_EXCLUDES == "nix";
assert configured.programs.nushell.extraEnv == "";
assert configured.programs.atuin.settings.sync_address == "https://atuin.jeeves.reo101.xyz";
assert configured.programs.atuin.settings.history_filter == [ "^ " ];
assert configured.programs.zsh.history.ignoreSpace;
assert
  configured.programs.zsh.autosuggestion.enable
  && configured.programs.zsh.fastSyntaxHighlighting.enable;
assert
  builtins.length (
    builtins.filter (
      package: toString package == toString configured.programs.gpg.package
    ) configured.home.packages
  ) == 1;
assert configured.services.gpg-agent.defaultCacheTtl == 7200;
assert configured.services.gpg-agent.maxCacheTtlSsh == 7200;
assert !configured.services.gpg-agent.enableZshIntegration;
assert !configured.services.gpg-agent.enableNushellIntegration;
assert !externallyEnabledAgent.services.gpg-agent.enableZshIntegration;
assert externalNushell.services.gpg-agent.enableNushellIntegration;
assert lib.hasInfix "export GPG_TTY=\"$TTY\"" externallyEnabledAgent.programs.zsh.initContent;
assert lib.hasInfix "$env.GPG_TTY" externallyEnabledAgent.programs.nushell.extraConfig;
assert
  configured.programs.starship.settings.vcs.order == [
    "jj"
    "git"
  ];
assert !(configured.programs.starship.settings ? custom);
assert !(configured.programs.starship.settings.time ? utc_time_offset);
assert configured.programs.starship.settings.username.show_always;
assert arm.rix101.shell.rebuildBackend == "nixos";
assert arm.rix101.shell.rebuildTarget == "cheetah-avf";
{
  checks = "passed";
  standalone = identity configured;
  withoutMetadata = identity withoutMetadata;
  explicitOverride = identity overridden;
  armNixos = identity arm;
}
