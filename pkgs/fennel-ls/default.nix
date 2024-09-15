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
    fennel = config.deps.lua.pkgs.fennel;
  };

  name = "fennel-ls";
  version = "0.1.2-dev";

  mkDerivation = {
    src = config.deps.fetchFromGitHub {
      owner = "reo101";
      repo = config.name;
      rev = "3099ba016b346696b8600dfbdffd9a66704f83f9";
      hash = "sha256-H5znjiYuQEbNG2WyTvH1CbnSk5PzaoPNg+xc+y66Gq0=";
    };

    makeFlags = [
      "PREFIX=$(out)"
      "LUA=${lib.getExe' config.deps.lua "lua"}"
      "FENNEL=${lib.getExe' config.deps.fennel "fennel"}"
      "EXE=${config.mkDerivation.meta.mainProgram}"
    ];

    nativeBuildInputs = with config.deps; [
    ];

    buildInputs = with config.deps; [
      # NOTE: `lua` and `fennel` provisioned using their corresponding `makeFlags`
    ];

    meta = with lib; {
      description = "A language server for intelligent editing of the Fennel Programming Language";
      homepage = "https://github.com/reo101/fennel-ls";
      license = licenses.mit;
      maintainers = with maintainers; [ reo101 ];
      inherit (config.deps.lua.meta) platforms;
      mainProgram = "fennel-ls";
    };
  };
}
