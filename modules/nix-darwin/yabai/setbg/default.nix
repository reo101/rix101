{ lib
, writeShellScriptBin
, symlinkJoin
, makeWrapper
, jq
, yabai
}:

let
  # NOTE: passing `${1}` because `${0}` resolves to the `.setbg-wrapped` path
  setWallpaperUnwrapped =
    writeShellScriptBin "setbg" ''
      osascript ${./setbg.scpt} "''${1}"
    '';
in
symlinkJoin {
  name = "setbg";
  paths = [ setWallpaperUnwrapped ];
  buildInputs = [ makeWrapper ];
  postBuild = ''
    wrapProgram $out/bin/setbg \
      --prefix PATH : ${lib.makeBinPath [
        jq
        yabai
      ]}
  '';
}
