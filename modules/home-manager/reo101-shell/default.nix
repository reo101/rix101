{ lib, pkgs, config, ... }:

let
  cfg = config.reo101.shell;
  inherit (lib)
    mkEnableOption mkOption types
    mkIf optionals optionalString;
in
{
  imports =
    [
    ];

  options =
    {
      reo101.shell = {
        enable = mkEnableOption "reo101 zsh setup";
        username = mkOption {
          description = "Username to be used (for prompt)";
          type = types.str;
          default = "${config.home.username}";
        };
        hostname = mkOption {
          description = "Hostname to be used (for `rebuild`)";
          type = types.nullOr types.str;
          default = null;
        };
        atuin = mkOption {
          description = "Integrate with atuin";
          type = types.bool;
          default = true;
        };
        direnv = mkOption {
          description = "Integrate with direnv";
          type = types.bool;
          default = true;
        };
        zoxide = mkOption {
          description = "Integrate with zoxide";
          type = types.bool;
          default = true;
        };
        flakePath = mkOption {
          description = "Flake path (for `rebuild`)";
          type = types.str;
          default = "${config.xdg.configHome}/rix101";
        };
        extraConfig = mkOption {
          description = "Extra zsh config";
          type = types.str;
          default = ''
          '';
        };
      };
    };

  config =
    mkIf cfg.enable {
      home.packages = with pkgs;
        builtins.concatLists [
          [
            zsh
            starship
          ]
          (optionals cfg.atuin [
            atuin
          ])
          (optionals cfg.direnv [
            direnv
          ])
          (optionals cfg.zoxide [
            zoxide
          ])
        ];

      # Atuin
      home.file."${config.xdg.configHome}/atuin/config.toml" = mkIf cfg.atuin {
        text = import ./atuin.nix {
          keyPath = "${config.xdg.dataHome}/atuin/key";
        };
      };

      # Direnv
      programs.direnv = mkIf cfg.direnv {
        enable = true;

        nix-direnv = {
          enable = true;
        };
      };

      # Starship
      programs.starship = {
        enable = true;

        settings = import ./starship.nix {
          inherit (cfg) username;
        };
      };

      # Zsh
      programs.zsh = {
        enable = true;
        enableCompletion = true;
        dotDir = ".config/zsh";

        shellAliases = {
          ls = "${pkgs.lsd}/bin/lsd";
          cp = "${pkgs.advcpmv}/bin/advcp -rvi";
          mv = "${pkgs.advcpmv}/bin/advmv -vi";
          mkdir = "mkdir -vp";
        };

        history = {
          size = 10000;
          path = "${config.xdg.dataHome}/zsh/history";
        };

        initExtra =
          builtins.concatStringsSep "\n"
            [
              ''
                rebuild () {
                  ${
                    let
                      inherit (lib.strings)
                        hasInfix;
                      inherit (pkgs.hostPlatform)
                        isx86_64 isAarch64
                        isLinux isDarwin;
                    in
                    if isx86_64 && isLinux then
                      "sudo --validate && sudo nixos-rebuild"
                    else if isDarwin then
                      "darwin-rebuild"
                    else if isAarch64 then
                      "nix-on-droid"
                    else
                      "home-manager"
                  } --flake ${
                    if cfg.hostname != null
                    then "${cfg.flakePath}#${cfg.hostname}"
                    else "${cfg.flakePath}"
                  } ''$''\{1:-switch''\} "''$''\{@:2''\}" |& nix run nixpkgs#nix-output-monitor
                }
              ''
              (optionalString cfg.atuin ''
                export ATUIN_NOBIND="true"
                eval "$(${pkgs.atuin}/bin/atuin init zsh)"
                function zvm_after_init() {
                  # bindkey "^r" _atuin_search_widget
                  zvm_bindkey viins "^R" _atuin_search_widget
                }
              '')
              # NOTE: done by `programs.direnv`
              # (optionalString cfg.direnv ''
              #   eval "$(${pkgs.direnv}/bin/direnv hook zsh)"
              # '')
              (optionalString cfg.zoxide ''
                eval "$(${pkgs.zoxide}/bin/zoxide init zsh)"
              '')
              cfg.extraConfig
            ];

        plugins = [
          {
            name = "zsh-nix-shell";
            file = "nix-shell.plugin.zsh";
            src = pkgs.fetchFromGitHub {
              owner = "chisui";
              repo = "zsh-nix-shell";
              rev = "v0.7.0";
              sha256 = "sha256-oQpYKBt0gmOSBgay2HgbXiDoZo5FoUKwyHSlUrOAP5E=";
            };
          }
          {
            name = "fast-syntax-highlighting";
            file = "fast-syntax-highlighting.plugin.zsh";
            src = pkgs.fetchFromGitHub {
              owner = "zdharma-continuum";
              repo = "fast-syntax-highlighting";
              rev = "cf318e06a9b7c9f2219d78f41b46fa6e06011fd9";
              sha256 = "sha256-RVX9ZSzjBW3LpFs2W86lKI6vtcvDWP6EPxzeTcRZua4=";
            };
          }
          {
            name = "zsh-autosuggestions";
            file = "zsh-autosuggestions.plugin.zsh";
            src = pkgs.fetchFromGitHub {
              owner = "zsh-users";
              repo = "zsh-autosuggestions";
              rev = "a411ef3e0992d4839f0732ebeb9823024afaaaa8";
              sha256 = "sha256-KLUYpUu4DHRumQZ3w59m9aTW6TBKMCXl2UcKi4uMd7w=";
            };
          }
          {
            name = "zsh-vi-mode";
            file = "zsh-vi-mode.plugin.zsh";
            src = pkgs.fetchFromGitHub {
              owner = "jeffreytse";
              repo = "zsh-vi-mode";
              rev = "1bda23100e8d140a19be0eed67395c64f6a6074c";
              sha256 = "sha256-3arAa5EBG+U9cCauChX9K0KF3hkd+t04/trlWKk/gOw=";
            };
          }
        ];
      };
    };

  meta = {
    maintainers = with lib.maintainers; [ reo101 ];
  };
}
