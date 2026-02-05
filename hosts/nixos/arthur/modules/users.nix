{ ... }:
let
  mainUser = "maria";
in
{
  # NOTE: <https://github.com/nix-community/impermanence/pull/223>
  # services.userborn.enable = true;

  # `UID`/`GID` allocation state (`declarative-users`, `uid-map`, etc.).
  environment.persistence."/persist".directories = [
    "/var/lib/nixos"
  ];

  users = {
    mutableUsers = true;
    users.${mainUser} = {
      isNormalUser = true;
      uid = 1000;
      initialHashedPassword = "$6$YLbFHpfNQggVJx9c$nothyvVyZNc9utLujBucKVaFxrRcAbLG1M2ZsrqRdTBbNvFFN6aut/JIY/EiP47EyumaG/VV9o8DawPjZZuZN0";

      extraGroups = [
        "wheel"
        "networkmanager"
        "audio"
        "video"
      ];

      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHBc0G9jbQYzwWqIzj504MrxsamFBzbISltpTrLaFUg1 cardno:31_228_281"
      ];
    };
  };

  security.sudo-rs = {
    enable = true;
    extraRules = [
      {
        users = [ mainUser ];
        commands = [
          {
            command = "ALL";
            options = [ "NOPASSWD" ];
          }
        ];
      }
    ];
  };
}
