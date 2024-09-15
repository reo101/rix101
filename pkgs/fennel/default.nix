{ config
, lib
, dream2nix
, ...
}: {
  imports = [
    dream2nix.modules.dream2nix.mkDerivation
  ];

  deps = { nixpkgs, ... }: {
    # Fetchers
    inherit (nixpkgs)
      fetchFromGitHub
      ;

    # Build inputs
    lua = nixpkgs.luajit;

    # # Check inputs
    # inherit (nixpkgs)
    #   fennel-ls
    #   ;
  };

  name = "Fennel";
  version = "1.5.2-dev";

  mkDerivation = {
    src = config.deps.fetchFromGitHub {
      owner = "reo101";
      repo = config.name;
      rev = "e8fd00ff52c07f8527989f8df6b57008b656f2d1";
      hash = "sha256-26pvDss6MQKiwNzjXX26yidFquFBBlZP7GvlxdwLMCI=";
    };

    makeFlags = [
      "PREFIX=$(out)"
      "LUA=${lib.getExe' config.deps.lua "lua"}"
    ];

    nativeBuildInputs = with config.deps; [
    ];

    buildInputs = with config.deps; [
    ];

    # FIXME:
    # > fennel-ls --check src/fennel.fnl src/fennel/parser.fnl src/fennel/specials.fnl src/fennel/utils.fnl src/fennel/compiler.fnl  src/fennel/macros.fnl src/fennel/match.fnl src/fennel/friend.fnl src/fennel/view.fnl src/fennel/repl.fnl src/launcher.fnl src/fennel/binary.fnl
    # > USAGE: fennel-ls [--lint file] [--server]

    # checkInputs = with config.deps; [
    #   fennel-ls
    # ];
    #
    # doCheck = true;

    meta = with lib; {
      description = " Lua Lisp Language ";
      homepage = "https://github.com/reo101/Fennel";
      license = licenses.mit;
      maintainers = with maintainers; [ reo101 ];
      mainProgram = "fennel";
    };
  };
}
