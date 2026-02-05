{
  inputs,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    inputs.hardware.nixosModules.framework-16-7040-amd
  ];

  hardware.cpu.amd.updateMicrocode = true;
  hardware.enableAllFirmware = true;
  hardware.enableRedistributableFirmware = lib.mkDefault true;

  hardware.bluetooth.enable = true;
  hardware.graphics.enable = true;
  hardware.keyboard.qmk.enable = true;

  services.fingerprint-led.enable = true;

  hardware.fw-fanctrl = {
    enable = true;
    config = {
      defaultStrategy = "banica";
      strategies = {
        "fire" = {
          fanSpeedUpdateFrequency = 5;
          movingAverageInterval = 10;
          speedCurve = [
            {
              temp = 40;
              speed = 30;
            }
            {
              temp = 90;
              speed = 50;
            }
          ];
        };
        "banica" = {
          fanSpeedUpdateFrequency = 5;
          movingAverageInterval = 10;
          speedCurve = [
            {
              temp = 40;
              speed = 15;
            }
            {
              temp = 55;
              speed = 30;
            }
            {
              temp = 65;
              speed = 50;
            }
            {
              temp = 70;
              speed = 65;
            }
            {
              temp = 75;
              speed = 100;
            }
          ];
        };
        "milinka" = {
          fanSpeedUpdateFrequency = 5;
          movingAverageInterval = 10;
          speedCurve = [
            {
              temp = 40;
              speed = 30;
            }
            {
              temp = 55;
              speed = 60;
            }
            {
              temp = 65;
              speed = 80;
            }
            {
              temp = 70;
              speed = 100;
            }
          ];
        };
        "ichiban" = {
          fanSpeedUpdateFrequency = 5;
          movingAverageInterval = 10;
          speedCurve = [
            {
              temp = 0;
              speed = 100;
            }
          ];
        };
      };
    };
  };
}
