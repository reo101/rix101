{
  description = "Shared self-hosted service modules used by server-style NixOS hosts";

  nixos.modules = [
    "slskd"
    "taskchampion-sync-server"
    "vaultwarden"
  ];
}
