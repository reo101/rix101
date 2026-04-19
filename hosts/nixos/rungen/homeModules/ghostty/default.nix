{
  inputs,
  lib,
  pkgs,
  config,
  ...
}:

let
  uiuaCodepointMap =
    (lib.concatStringsSep "," (import ./uiua386glyphs.nix))
    + "=Uiua386";
in
{
  programs.ghostty = {
    enable = true;
    package = pkgs.ghostty;
    settings = {
      background-opacity = 0.65;
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
            (lib.map (lib.path.append ./shaders))
            (lib.map builtins.toString)
          ];
    };
    systemd = {
      enable = true;
    };
  };
  stylix.targets.ghostty.enable = false;

}
