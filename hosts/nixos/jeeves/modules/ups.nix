{
  lib,
  pkgs,
  config,
  ...
}:

let
  user = "jeeves";
in
{
  age.secrets."jeeves.ups" = {
    rekeyFile = lib.custom.repoSecret "home/jeeves/ups/jeeves.age";
  };

  power.ups = {
    enable = true;

    users = {
      ${user} = {
        passwordFile = config.age.secrets."jeeves.ups".path;
        upsmon = "primary";
        actions = [ "SET" ];
        instcmds = [ "ALL" ];
      };
    };

    ups.apc1500 = {
      driver = "usbhid-ups";
      port = "auto";
    };

    upsmon.monitor.apc1500 = {
      inherit user;
    };

    upsd = {
      enable = true;
      listen = [
        { address = "0.0.0.0"; }
      ];
    };
  };

  systemd.services = {
    upsdrv.after = lib.mkForce [ "network.target" ];
    upsd.after = lib.mkForce [
      "network.target"
      "upsdrv.service"
    ];
    upsmon.after = lib.mkForce [
      "network.target"
      "upsd.service"
    ];
  };
}
