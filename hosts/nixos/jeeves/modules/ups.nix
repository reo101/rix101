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
        { address = "127.0.0.1"; }
        { address = "::1"; }
        { address = "10.0.0.1"; }
      ];
    };
  };

  # HACK: wait for the HA `microvm` tap/bridge plumbing before starting `upsd`
  systemd.services = {
    upsdrv.after = lib.mkForce [ "network.target" ];
    upsd-wait-microvm-address = {
      description = "Wait for microvm bridge address";
      after = [
        "network.target"
        "microvm-tap-interfaces@hass.service"
      ];
      wants = [ "microvm-tap-interfaces@hass.service" ];
      before = [ "upsd.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = pkgs.writeShellScript "wait-for-microvm-address" ''
          for _ in $(seq 1 30); do
            ${lib.getExe' pkgs.iproute2 "ip"} -o -4 addr show dev microvm | ${lib.getExe pkgs.gnugrep} -q '10\.0\.0\.1/24' && exit 0
            sleep 1
          done

          echo "microvm bridge address 10.0.0.1/24 not ready" >&2
          exit 1
        '';
      };
    };
    upsd = {
      after = lib.mkForce [
        "network.target"
        "upsdrv.service"
        "upsd-wait-microvm-address.service"
      ];
      requires = [ "upsd-wait-microvm-address.service" ];
    };
    upsmon.after = lib.mkForce [
      "network.target"
      "upsd.service"
    ];
  };
}
