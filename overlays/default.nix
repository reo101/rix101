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
