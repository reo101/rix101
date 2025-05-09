{
  lib,
  buildHomeAssistantComponent,
  fetchFromGitHub,
  jq,
  moreutils,
  python3Packages,
}:

buildHomeAssistantComponent rec {
  owner = "kongo09";
  domain = "philips_airpurifier_coap";
  version = "0.34.3";

  src = fetchFromGitHub {
    inherit owner;
    repo = "philips-airpurifier-coap";
    tag = "v${version}";
    hash = "sha256-jZmFvozkmmCCeKmdOV/FKXj0V8iGP3tnAqED/PBZrrY=";
  };

  dependencies = [
    python3Packages.aioairctrl
    python3Packages.getmac
  ];

  postPatch = ''
    manifest=./custom_components/philips_airpurifier_coap/manifest.json

    ${lib.getExe jq} \
      '.requirements |= map(sub("getmac==0\\.9\\.4"; "getmac==0.9.5"))' \
      $manifest \
      | ${lib.getExe' moreutils "sponge"} $manifest
  '';

  meta = with lib; {
    description = "Home Assistant custom component for Philips AirPurifier devices via CoAP";
    homepage = "https://github.com/kongo09/philips-airpurifier-coap";
    changelog = "https://github.com/kongo09/philips-airpurifier-coap/releases/tag/v${version}";
    license = licenses.mit;
    maintainers = with maintainers; [ ];
  };
}
