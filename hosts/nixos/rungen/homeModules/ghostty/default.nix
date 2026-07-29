{
  inputs,
  lib,
  pkgs,
  config,
  ...
}:

let
  shaderDir = builtins.path {
    path = ./shaders;
    name = "ghostty-shaders";
  };
  uiuaCodepointMap =
    (lib.concatStringsSep "," (import ./uiua386glyphs.nix))
    + "=Uiua386";
in
{
  programs.ghostty = {
    enable = true;
    package = pkgs.ghostty;
    settings = {
      # TODO: setup from stylix.opacity
      background-opacity = 0.65;
      background-opacity-cells = true;
      # 100 MiB per terminal surface
      scrollback-limit = 100 * 1024 * 1024;

      font-family = [
        "Maple Mono NF CN"
      ];
      font-codepoint-map = [
        uiuaCodepointMap
      ];
      adjust-box-thickness = 2;
      gtk-single-instance = true;
      keybind = [
        "shift+enter=text:\\x1b\\r"
      ];
      custom-shader =
        lib.pipe
          [
            "cursor_jumpy.glsl"
            "sharpen.glsl"
          ]
          [
            (lib.map (shader: "${shaderDir}/${shader}"))
            (lib.map builtins.toString)
          ];
    };
    systemd = {
      enable = true;
    };
  };

  # BUG: `red` in the `stylix` theme is gray
  stylix.targets.ghostty.enable = false;
}
