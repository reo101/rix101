{ pkgs
, lib
, stdenv
, makeWrapper
, nushell
, coreutils
, ...
}:

stdenv.mkDerivation rec {
  pname = "jj-gen-fix-config";
  version = "0.1.0";

  src = ./.;

  nativeBuildInputs = [
    makeWrapper
  ];

  buildInputs = [
    nushell
    coreutils
  ];

  installPhase = ''
    mkdir -p $out/bin
    cp jj-gen-fix-config.nu $out/bin/
    chmod +x $out/bin/jj-gen-fix-config.nu

    makeWrapper ${lib.getExe nushell} $out/bin/jj-gen-fix-config \
      --add-flags "-n" \
      --add-flags "$out/bin/jj-gen-fix-config.nu" \
      --prefix PATH : ${lib.makeBinPath [ coreutils ]}
  '';

  meta = with lib; {
    description = "Generate jj fix config from .pre-commit-config.yaml";
    license = licenses.mit;
    maintainers = [ maintainers.reo101 ];
    platforms = platforms.all;
  };
}
