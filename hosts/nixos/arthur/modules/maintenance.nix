{ pkgs, ... }:
{
  nix = {
    package = pkgs.nixVersions.latest;
    settings = {
      experimental-features = [
        "flakes"
        "nix-command"
        "auto-allocate-uids"
        "ca-derivations"
      ];
      auto-optimise-store = true;
    };
  };

  age.identityPaths = [
    "/persist/etc/ssh/ssh_host_ed25519_key"
  ];

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
    };
  };

  # Persist only the host keys, NOT the directory — bind-mounting the whole
  # `/etc/ssh/` would hide `sshd_config` (a NixOS-managed symlink into the
  # Nix store), causing sshd to fail with "No such file or directory".
  # The keys must survive reboots so remote clients don't see a host-key
  # mismatch on every boot.
  environment.persistence."/persist".files = [
    "/etc/ssh/ssh_host_ed25519_key"
    "/etc/ssh/ssh_host_ed25519_key.pub"
    "/etc/ssh/ssh_host_rsa_key"
    "/etc/ssh/ssh_host_rsa_key.pub"
  ];
}
