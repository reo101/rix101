{ pkgs, ... }:
{
  programs.zsh.enable = true;

  # YubiKey smartcard support for GPG/SSH-backed auth.
  services.pcscd.enable = true;

  users = {
    mutableUsers = false;
    users.reo101 = {
      isNormalUser = true;
      uid = 1001;
      shell = pkgs.zsh;
      group = "reo101";
      description = "Pavel Atanasov";
      hashedPassword = "$y$j9T$hgTABX.vnieAghr5E7mVF0$DTI5JWE4K4kd1MxW5xbcYHW7ZLfp/HvTvOTAQRgzcsD";
      extraGroups = [
        "wheel"
        "audio"
        "video"
        "users"
      ];
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHBc0G9jbQYzwWqIzj504MrxsamFBzbISltpTrLaFUg1 cardno:31_228_281"
      ];
    };
    groups.reo101 = { };
  };
}
