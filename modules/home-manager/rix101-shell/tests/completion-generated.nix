# Test the generated completion/direnv/Carapace integration without rebuilding
# unrelated prompt, history, or VCS packages and without activating anything.
let
  flake = builtins.getFlake (toString ../../../..);
  pkgs = flake.nixosConfigurations.rungen.pkgs;
  lib = pkgs.lib;
  configuration = (flake.inputs.home-manager.lib.homeManagerConfiguration {
    inherit pkgs;
    modules = [
      ../default.nix
      {
        home.username = "completion-regression";
        home.homeDirectory = "/tmp/rix101-completion-regression-home";
        home.stateVersion = "26.05";
        rix101.shell = {
          enable = true;
          shells = [ "zsh" ];
          starship = false;
          atuin = false;
          zoxide = false;
          zellij = false;
        };
      }
    ];
  }).config;
  homeDirectory = configuration.home.homeDirectory;
  zshrc = configuration.home.file.".config/zsh/.zshrc".source;
  plugins = lib.concatMapStringsSep "\n" (plugin: ''
    mkdir -p "$ZDOTDIR/plugins"
    ln -s ${plugin.src} "$ZDOTDIR/plugins/${plugin.name}"
  '') configuration.programs.zsh.plugins;
in
pkgs.runCommand "rix101-shell-completion-generated-tests" {
  nativeBuildInputs = [ configuration.programs.zsh.package pkgs.coreutils ];
} ''
  export HOME="$TMPDIR/home"
  export XDG_CONFIG_HOME="$HOME/.config"
  export XDG_DATA_HOME="$HOME/.local/share"
  export XDG_CACHE_HOME="$HOME/.cache"
  export ZDOTDIR="$XDG_CONFIG_HOME/zsh"
  export XDG_DATA_DIRS=""
  export NIX_PROFILES=""
  export SHLVL=10
  mkdir -p "$ZDOTDIR" "$XDG_CACHE_HOME"
  ${plugins}
  substitute ${zshrc} "$TMPDIR/zshrc" \
    --replace-fail ${lib.escapeShellArg homeDirectory} "$HOME"
  zsh -dfi ${./completion-generated.zsh} "$TMPDIR/zshrc"
  touch "$out"
''
