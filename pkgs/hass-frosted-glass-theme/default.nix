{ lib, stdenvNoCC, fetchFromGitHub }:

stdenvNoCC.mkDerivation rec {
  pname = "hass-frosted-glass-theme";
  version = "1.3";

  src = fetchFromGitHub {
    owner = "wessamlauf";
    repo = "homeassistant-frosted-glass-themes";
    tag = "v${version}";
    hash = "sha256-LttvLCnn9Necem2BkVVDHpEmBDeiLpqBvi59h92r0i4=";
  };

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/themes
    cp -r themes/*.yaml $out/themes/
    cp -r themes/*.jpg $out/themes/

    runHook postInstall
  '';

  meta = with lib; {
    description = "Beautiful and modern frosted glass theme for Home Assistant";
    homepage = "https://github.com/wessamlauf/homeassistant-frosted-glass-themes";
    changelog = "https://github.com/wessamlauf/homeassistant-frosted-glass-themes/releases/tag/v${version}";
    license = licenses.mit;
    maintainers = with maintainers; [ reo101 ];
    platforms = platforms.all;
  };
}
