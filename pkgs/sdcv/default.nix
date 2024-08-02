{ config
, lib
, dream2nix
, ...
}: {
  imports = [
    dream2nix.modules.dream2nix.mkDerivation
  ];

  deps = { nixpkgs, ... }: {
    inherit (nixpkgs)
      # Fetchers
      fetchFromGitHub
      # Build inputs
      cmake
      pkg-config
      iconv
      pcre
      readline
      glib
      zlib
      ;
  };

  name = "sdcv";
  version = "0.5.5";

  mkDerivation = {
    src = config.deps.fetchFromGitHub {
      owner = "Dushistov";
      repo = config.name;
      rev = "v${config.version}";
      hash = "sha256-EyvljVXhOsdxIYOGTzD+T16nvW7/RNx3DuQ2OdhjXJ4=";
    };

    nativeBuildInputs = with config.deps; [
      pkg-config
      cmake
      iconv
    ];

    buildInputs = with config.deps; [
      pcre
      readline
      glib
      zlib
    ];

    cmakeFlags = [
      # FIXME: <https://github.com/Dushistov/sdcv/blob/49c8094b53b7dd90efeabeaf276752a650a0f931/CMakeLists.txt#L58> does not exit
      "-DENABLE_NLS=OFF"
    ];

    meta = with lib; {
      description = "Console version of StarDict";
      homepage = "https://github.com/Dushistov/sdcv";
      license = licenses.gpl2;
      maintainers = with maintainers; [ reo101 ];
    };
  };
}
