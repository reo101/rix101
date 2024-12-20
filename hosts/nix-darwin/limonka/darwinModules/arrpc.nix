{ pkgs, lib, ... }:

{
  environment.systemPackages = with pkgs; [
    arrpc
  ];

  launchd.user.agents.arrpc = {
    script = lib.getExe pkgs.arrpc;
    serviceConfig = {
      Label = "org.nixos.arrpc";
      RunAtLoad = true;
      KeepAlive = true;
    };
  };
}
