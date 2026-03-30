{
  lib,
  pkgs,
  ...
}:

let
  bootstrapRuntimeDir = "/run/iso-bootstrap";
  bootstrapHostkeyPath = "${bootstrapRuntimeDir}/ssh_host_ed25519_key";
  bootstrapSecretFile = lib.custom.repoSecret "home/iso/bootstrap/ssh_host_ed25519_key.age";
  bootstrapPubkeyFile = lib.custom.repoSecret "home/iso/bootstrap/ssh_host_ed25519_key.pub";
  bootstrapPubkey = lib.pipe bootstrapPubkeyFile [
    builtins.readFile
    lib.trim
  ];
  yubikeyIdentities = pkgs.writeText "iso-yubikey-identities" ''
    ${builtins.readFile ../../../../secrets/identities/01-age-yubikey-1-identity-20250322.pub}
    ${builtins.readFile ../../../../secrets/identities/02-age-yubikey-2-identity-bb8456bc.pub}
  '';
  isoUnlockApply = pkgs.writeShellApplication {
    name = "iso-unlock-apply";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.systemd
    ];
    text = ''
      set -eu

      if [ "$#" -ne 2 ]; then
        echo "usage: iso-unlock-apply <private-key> <public-key>" >&2
        exit 64
      fi

      install -D -m 0600 "$1" ${bootstrapHostkeyPath}
      install -D -m 0644 "$2" ${bootstrapHostkeyPath}.pub

      systemctl restart agenix-install-secrets.service
      systemctl restart sshd.service
      systemctl restart iso-wireguard-refresh.service
    '';
  };
  isoUnlock = pkgs.writeShellApplication {
    name = "iso-unlock";
    runtimeInputs = [
      pkgs.age-plugin-yubikey
      pkgs.coreutils
      pkgs.openssh
      pkgs.rage
    ];
    text = ''
      set -eu

      tmp_dir="$(mktemp -d)"
      tmp_key="$tmp_dir/ssh_host_ed25519_key"
      tmp_pub="$tmp_dir/ssh_host_ed25519_key.pub"
      trap 'rm -rf "$tmp_dir"' EXIT

      rage -d \
        -i ${yubikeyIdentities} \
        -o "$tmp_key" \
        ${bootstrapSecretFile}

      chmod 0600 "$tmp_key"
      ssh-keygen -y -f "$tmp_key" > "$tmp_pub"
      test "$(cat "$tmp_pub")" = ${lib.escapeShellArg bootstrapPubkey}

      if [ "$(id -u)" -eq 0 ]; then
        exec ${lib.getExe isoUnlockApply} "$tmp_key" "$tmp_pub"
      fi

      exec /run/wrappers/bin/sudo ${lib.getExe isoUnlockApply} "$tmp_key" "$tmp_pub"
    '';
  };
in
{
  environment.systemPackages = [
    pkgs.age-plugin-yubikey
    pkgs.rage
    isoUnlock
  ];

  services.userborn.enable = true;

  services.openssh = {
    generateHostKeys = false;
    hostKeys = [
      {
        path = bootstrapHostkeyPath;
        type = "ed25519";
      }
    ];
  };

  age.identityPaths = [ bootstrapHostkeyPath ];

  systemd.services.agenix-install-secrets = {
    wantedBy = lib.mkForce [ ];
  };

  systemd.services.iso-wireguard-refresh.wantedBy = lib.mkForce [ ];

  security.sudo.extraRules = [
    {
      users = [ "reo101" ];
      commands = [
        {
          command = lib.getExe isoUnlockApply;
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];
}
