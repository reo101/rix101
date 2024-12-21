{ lib
, pkgs
, fetchFromGitHub
, writeShellScript
, writeShellScriptBin
, sbarlua
, ...
}:
let
  lua = sbarlua.passthru.luaPackages.lua;
  fennel = sbarlua.passthru.luaPackages.fennel;
in
  writeShellScriptBin "sketchybar-config" ''
    ${lib.getExe' fennel "fennel"} \
      --add-package-cpath "${sbarlua}/${sbarlua.moduleDir}/?.so" \
      --add-fennel-path "${./config}/?.fnl" \
      --add-fennel-path "${./config}/?/init.fnl" \
      ${./config}/init.fnl
  ''
