{ lib
, clang
, fetchFromGitHub
, gcc
, readline
, pkgs
}:
let
  luaPackages = pkgs.lua54Packages;
  lua = luaPackages.lua;
in
lua.stdenv.mkDerivation (finalAttrs: {
  pname = "SBarLua";
  version = "0-unstable-2024-08-12";

  name = "lua${lua.luaversion}-${finalAttrs.pname}-${finalAttrs.version}";

  src = lib.sources.cleanSourceWith {
    src = fetchFromGitHub {
      owner = "FelixKratz";
      repo = "SbarLua";
      rev = "437bd2031da38ccda75827cb7548e7baa4aa9978";
      hash = "sha256-F0UfNxHM389GhiPQ6/GFbeKQq5EvpiqQdvyf7ygzkPg=";
    };
    # NOTE: exclude vendored `lua` since we provide our own
    # FIXME: acutally no, `Makefile` tries to `cd` and `make` there
    # filter = name: type: !(lib.hasPrefix "lua-5.4.7" (builtins.baseNameOf name));
    filter = name: type: true;
  };

  nativeBuildInputs = [
    clang
    gcc
  ];

  buildInputs = [
    readline
  ];

  propagatedBuildInputs = [
    lua
  ];

  makeFlags = [
    "PREFIX=$(out)"
    "LUA_INC=-I${lua}/include"
    # "LUA_DIR=?"
    "LUA_LIBDIR=$(out)/${finalAttrs.passthru.moduleDir}"
    "LUA_VERSION=${lua.luaversion}"
  ];

  installPhase = ''
    mkdir -p $out/${finalAttrs.passthru.moduleDir}/
    cp -r bin/* $out/${finalAttrs.passthru.moduleDir}/
  '';

  # NOTE: Add passthru attributes to expose important paths
  passthru = rec {
    # Expose the module directory
    moduleDir = "lib/lua/lua${lua.luaversion}";
    # Expose the full path to the specific module
    modulePath = "${moduleDir}/sketchybar.so";
    # Expose the used `luaPackages`
    inherit luaPackages;
  };
})
