{
  lib,
  buildHomeAssistantComponent,
  fetchFromGitHub,
  python3Packages,
}:

buildHomeAssistantComponent rec {
  owner = "nicolas-stein";
  domain = "philips_airplus";
  version = "0.1.1";

  src = fetchFromGitHub {
    inherit owner;
    repo = "philips-airplus-homeassistant";
    rev = "d8c3cce5a2946c33747dcaa7c22bcbaaddc47dae";
    hash = "sha256-Lt5MGKNA9mkCe4QyNunDXWz+we2pAgkljKCsq94evfQ=";
  };

  dependencies = [
    python3Packages.paho-mqtt
  ];

  meta = with lib; {
    description = "Home Assistant custom component for Philips Air+ air purifiers via cloud API";
    homepage = "https://github.com/nicolas-stein/philips-airplus-homeassistant";
    license = licenses.mit;
    maintainers = with maintainers; [ ];
  };
}
