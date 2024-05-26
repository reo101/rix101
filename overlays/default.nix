# This file defines overlays
{ inputs, outputs, ... }:
{
  # This one brings our custom packages from the 'pkgs' directory
  additions = final: _prev: import ../pkgs {
    pkgs = final;
  };

  # This one contains whatever you want to overlay
  # You can change versions, add patches, set compilation flags, anything really.
  # https://nixos.wiki/wiki/Overlays
  modifications = final: prev: {
    # example = prev.example.overrideAttrs (oldAttrs: rec {
    # ...
    # });

    lib = prev.lib // {
      maintainers = {
        reo101 = {
          name = "Pavel Atanasov";
          email = "pavel.atanasov2001@gmail.com";
          github = "reo101";
          githubId = "37866329";
          keys = [
            {
              fingerprint = "8A29 0250 C775 7813 1DD1  DC57 7275 0ABE E181 26D0";
            }
          ];
        };
      };
    };

    nix-monitored = inputs.nix-monitored.packages.${final.system}.default.override {
      nix = prev.nix;
      nix-output-monitor = prev.nix-output-monitor;
    };

    nixVersions = prev.nixVersions // final.lib.flip final.lib.concatMapAttrs prev.nixVersions (version: package:
        final.lib.optionalAttrs
          (final.lib.and
            (final.lib.all (prefix: ! final.lib.hasPrefix prefix version)
              # TODO: smarter filtering of deprecated and non-packages
              [
                "nix_2_4"
                "nix_2_5"
                "nix_2_6"
                "nix_2_7"
                "nix_2_8"
                "nix_2_9"
                "nix_2_10"
                "nix_2_11"
                "nix_2_12"
                "nix_2_13"
                "nix_2_14"
                "nix_2_15"
                "nix_2_16"
                "nix_2_17"
                "unstable"
              ])
            (final.lib.isDerivation package))
          {
            "${version}-monitored" = inputs.nix-monitored.packages.${final.system}.default.override {
              nix = package;
              nix-output-monitor = prev.nix-output-monitor;
            };
          }
    );

    river = prev.river.overrideAttrs (oldAttrs: rec {
      xwaylandSupport = true;
    });

    discord = prev.discord.override {
      withOpenASAR = true;
      withVencord = true;
    };

    prismlauncher = prev.prismlauncher.overrideAttrs (oldAttrs: {
      patches = (oldAttrs.patches or [ ]) ++ [
        ./offline-mode-prism-launcher.diff
      ];
    });
  };
}
