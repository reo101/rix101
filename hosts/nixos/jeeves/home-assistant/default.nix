{ inputs, lib, pkgs, config, ... }:
{
  environment.systemPackages = with pkgs; [
  ];

  nixpkgs.config.permittedInsecurePackages = [
    "openssl-1.1.1w"
  ];

  services.home-assistant = {
    enable = true;
    extraComponents = [
      # Components required to complete the onboarding
      "esphome"
      "met"
      "radio_browser"
      "tuya"
    ];
    config = {
      # Includes dependencies for a basic setup
      # https://www.home-assistant.io/integrations/default_config/
      default_config = { };
      mobile_app = { };
      map = { };
    };
  };

  networking.firewall =
    lib.pipe
      [ "TCP" "UDP" ]
      [
        (builtins.map
          (protocol:
            lib.nameValuePair
              "allowed${protocol}Ports"
              [ 8123 ]))
        builtins.listToAttrs
      ];
}
