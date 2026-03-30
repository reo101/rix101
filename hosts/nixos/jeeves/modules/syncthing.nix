{ config, ... }:

let
  user = "syncthing";
  group = "users";
  dataDir = "/data/syncthing";
  stateDir = "/data/.state/syncthing";
  configDir = "${stateDir}/config";
in
{
  services.syncthing = {
    enable = true;
    inherit user group dataDir configDir;
    databaseDir = stateDir;
    guiAddress = "127.0.0.1:8384";
    openDefaultPorts = true;

    # NOTE: Configure peers and folders in the Syncthing UI
    overrideDevices = false;
    overrideFolders = false;

    # NOTE: Disable global discovery
    settings.options = {
      globalAnnounceEnabled = false;
      localAnnounceEnabled = true;
      relaysEnabled = false;
      natEnabled = false;
      urAccepted = -1;
    };
  };

  systemd.tmpfiles.settings."syncthing" = {
    "${dataDir}".d = {
      user = user;
      group = group;
      mode = "0755";
    };
    "${stateDir}".d = {
      user = user;
      group = group;
      mode = "0700";
    };
    "${configDir}".d = {
      user = user;
      group = group;
      mode = "0700";
    };
  };

  systemd.services.syncthing.unitConfig.RequiresMountsFor = [
    dataDir
    stateDir
  ];
}
