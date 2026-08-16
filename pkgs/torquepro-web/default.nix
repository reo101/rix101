{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  php,
  coreutils,
  writeShellScript,
}:

let
  phpPackage = php.withExtensions (
    { enabled, all }:
    enabled
    ++ (with all; [
      mysqli
      pdo_mysql
    ])
  );
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "torquepro-web";
  version = "0-unstable-2026-08-09";

  src = fetchFromGitHub {
    owner = "reo101";
    repo = "torquepro-web";
    rev = "04e2af4c711b4b4586318630c7eb7db5b67d70ac";
    hash = "sha256-f2FA3Cp+hKj8Gorre51EH1ISh8GA+asV3I6WG+K5/Go=";
  };

  nativeCheckInputs = [ phpPackage ];
  doCheck = true;

  checkPhase = ''
    php -d display_errors=stderr -d error_reporting=E_ALL tests/regression.php
  '';

  installPhase = ''
    mkdir -p $out/share
    cp -r . $out/share/torquepro-web
  '';

  passthru = {
    inherit phpPackage;
    schema = "${finalAttrs.finalPackage}/share/torquepro-web/schema.sql";
    services.default = {
      imports = [
        phpPackage.services.default
        (lib.modules.importApply ./service.nix {
          inherit coreutils writeShellScript;
        })
      ];
      php-fpm.package = phpPackage;
      torquepro-web.package = finalAttrs.finalPackage;
    };
  };

  meta = {
    description = "Web data logger and automotive sensor analysis workbench for Torque Pro";
    homepage = "https://github.com/reo101/torquepro-web";
    license = lib.licenses.unfree;
    maintainers = with lib.maintainers; [ reo101 ];
    platforms = lib.platforms.linux;
  };
})
