{
  lib,
  buildHomeAssistantComponent,
  fetchFromGitHub,
  home-assistant,
}:

buildHomeAssistantComponent rec {
  owner = "ShorMeneses";
  domain = "philips_airplus";
  version = "0.3.0";

  # WARN: `buildHomeAssistantComponent`'s manifest hook reads `domain` from the environment
  __structuredAttrs = false;

  src = fetchFromGitHub {
    inherit owner;
    repo = "philips-airplus-homeassistant";
    rev = "99c6b01e4f305142c221b8764c59d3ba31b3ce8a";
    hash = "sha256-Nr7+F9EtTJT8PCJVvcFrh9R8B+k2UbrasVWelJ8DAJc=";
  };

  dependencies = [
    home-assistant.python3Packages.paho-mqtt
  ];

  meta = with lib; {
    description = "Home Assistant custom component for Philips Air+ air purifiers via cloud API";
    homepage = "https://github.com/ShorMeneses/philips-airplus-homeassistant";
    changelog = "https://github.com/ShorMeneses/philips-airplus-homeassistant/commits/master";
    license = licenses.mit;
    maintainers = with maintainers; [ ];
  };
}
