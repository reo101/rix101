{ lib
, pkgs
, fetchFromGitHub
, writeShellScript
, writeShellScriptBin
, sbarlua
, ...
}:
let
  luaPkgs = sbarlua.passthru.luaModule.pkgs;
  lua = luaPkgs.lua;
  fennel = luaPkgs.fennel;
in
  writeShellScriptBin "sketchybar-config" ''
    ${lib.getExe' fennel "fennel"} \
      --add-package-cpath "${sbarlua}/lib/lua/${sbarlua.luaModule.luaversion}/?.so" \
      --add-fennel-path "${./config}/?.fnl" \
      --add-fennel-path "${./config}/?/init.fnl" \
      ${./config}/init.fnl
  ''
