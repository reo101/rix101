{
  lib,
  symlinkJoin,
  makeWrapper,
  writeText,
  openssl,
  opensc,
  pkcs11-provider,
}:

let
  opensslConf = writeText "openssl-pkcs11.cnf" /* ini */ ''
    openssl_conf = openssl_init
    [openssl_init]
    providers = provider_sect
    [provider_sect]
    default = default_sect
    pkcs11 = pkcs11_sect
    [default_sect]
    activate = 1
    [pkcs11_sect]
    module = ${pkcs11-provider}/lib/ossl-modules/pkcs11.so
    pkcs11-module-path = ${opensc}/lib/opensc-pkcs11.so
    pkcs11-module-login-behavior = always
    pkcs11-module-cache-pins = cache
    activate = 1
  '';
in
symlinkJoin {
  name = "openssl-pkcs11-${openssl.version}";
  paths = [ openssl ];
  nativeBuildInputs = [ makeWrapper ];
  postBuild = ''
    wrapProgram "$out/bin/openssl" \
      --set-default OPENSSL_CONF ${opensslConf}
  '';
  passthru = {
    inherit opensslConf;
  };
  meta = builtins.removeAttrs openssl.meta [ "outputsToInstall" ] // {
    description = "OpenSSL CLI with pkcs11-provider/OpenSC preconfigured";
    mainProgram = "openssl";
  };
}
