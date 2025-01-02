{ inputs, lib, pkgs, config, ... }:

{
  imports = [
  ];

  environment.packages = with pkgs; [ ];

  # Backup etc files instead of failing to activate generation if a file already exists in /etc
  environment.etcBackupExtension = ".bak";

  # Remove motd
  environment.motd = null;

  # # Set $EDITOR
  # environment.variables.EDITOR = "nvim";

  user.shell = "${pkgs.zsh}/bin/zsh";

  environment.sessionVariables = let
    dnshack = pkgs.callPackage "${inputs.dnshack.outPath}" { };
  in {
    DNSHACK_RESOLVER_CMD = "${dnshack}/bin/dnshackresolver";
    LD_PRELOAD = "${dnshack}/lib/libdnshackbridge.so";
  };

  # Read the changelog before changing this value
  system.stateVersion = "22.11";

  nix.extraOptions = ''
    experimental-features = ${
      builtins.concatStringsSep " " [
        "nix-command"
        "flakes"
        "recursive-nix"
        # NOTE: not in `lix`, yet
        # "pipe-operators"
      ]
    }

    keep-outputs = true
    keep-derivations = true

    # Remote builders
    builders = ${
      # TODO: <https://nix.dev/manual/nix/2.18/advanced-topics/distributed-builds>
      builtins.concatStringsSep " ; " [
        "ssh://jeeves@jeeves.lan           x86_64-linux,aarch64-linux - 16 6 benchmark,big-parallel,kvm,nixos-test -"
        "ssh://pavelatanasov@limonka.local aarch64-darwin             - 4  3 nixos-test                            -"
      ]
    }
    builders-use-substitutes = true
  '';

  nix.package = pkgs.lix-monitored;

  time.timeZone = "Europe/Sofia";

  terminal.font = "${pkgs.nerd-fonts.fira-code}/share/fonts/truetype/NerdFonts/FiraCode/FiraCodeNerdFont-Regular.ttf";
}
