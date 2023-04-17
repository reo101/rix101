# This file defines overlays
{ inputs, outputs, ... }:
{
  # This one brings our custom packages from the 'pkgs' directory
  additions = final: _prev: import ../pkgs { pkgs = final; };

  # This one contains whatever you want to overlay
  # You can change versions, add patches, set compilation flags, anything really.
  # https://nixos.wiki/wiki/Overlays
  modifications = final: prev: {
    # example = prev.example.overrideAttrs (oldAttrs: rec {
    # ...
    # });
    river = prev.river.overrideAttrs (oldAttrs: rec {
      xwaylandSupport = true;
    });

    # armcord = prev.armcord.overrideAttrs (oldAttrs: let
    #   openasar = final.fetchurl {
    #     url = "https://github.com/GooseMod/OpenAsar/releases/download/nightly/app.asar";
    #     sha256 = final.lib.fakeSha256;
    #   };
    # in rec {
    #   postInstall = (oldAttrs.postInstall or "") ++ ''
    #     install -v "${openasar}" "$out/opt/Discord/resources/app.asar"
    #   '';
    # });

    prismlauncher = prev.prismlauncher.overrideAttrs (oldAttrs: {
      patches = (oldAttrs.patches or [ ]) ++ [
        ./offline-mode-prism-launcher.diff
      ];
    });
  };
}
