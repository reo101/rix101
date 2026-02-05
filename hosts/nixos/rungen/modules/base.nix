{
  inputs,
  pkgs,
  lib,
  ...
}:
{
  programs.zsh.enable = true;

  programs.firefox.enable = true;

  # YibiKey
  services.pcscd = {
    enable = true;
  };

  environment.pathsToLink = [
    "/share/applications"
    "/share/xdg-desktop-portal"
  ];

  users = {
    mutableUsers = false;
    users.reo101 = {
      isNormalUser = true;
      uid = 1002;
      shell = pkgs.zsh;
      group = "reo101";
      description = "Pavel Atanasov";
      hashedPassword = "$y$j9T$hgTABX.vnieAghr5E7mVF0$DTI5JWE4K4kd1MxW5xbcYHW7ZLfp/HvTvOTAQRgzcsD";
      extraGroups = [
        "wheel"
        "audio"
        "video"
      ];
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIN2SviyDaz+wZpQpn9PwYnz/Jl4C4MsxiK6A2NmfRKY2 root@rungen"
      ];
    };
    groups.reo101 = {};
  };

  virtualisation.vmVariantWithDisko = {
    users.users.reo101.initialHashedPassword = "$y$j9T$hgTABX.vnieAghr5E7mVF0$DTI5JWE4K4kd1MxW5xbcYHW7ZLfp/HvTvOTAQRgzcsD";
  };

  security.sudo-rs = {
    enable = true;
    extraRules = [
      {
        users = [ "reo101" ];
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
