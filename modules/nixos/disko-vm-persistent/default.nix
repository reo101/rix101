{
  config,
  lib,
  pkgs,
  options,
  ...
}:

lib.mkIf (options ? disko) {
  disko = {
    memSize = lib.mkDefault 2048;
    imageBuilder.copyNixStoreThreads = lib.mkDefault 8;
  };

  # Persistent-disk variant of vmWithDisko — survives VM restarts so you can
  # test hibernation (resume from swap) and impermanence rollback across reboots.
  #   nix run .#nixosConfigurations.<host>.config.system.build.vmWithDiskoPersistent
  #   nix run .#nixosConfigurations.<host>.config.system.build.vmWithDiskoPersistent -- --reset
  system.build.vmWithDiskoPersistent =
    let
      vmVariant = config.virtualisation.vmVariantWithDisko;
      diskoImages = vmVariant.system.build.diskoImages;
      vmRunner = vmVariant.system.build.vm;
      diskNames = builtins.attrNames config.disko.devices.disk;
      inherit (config.networking) hostName;
    in
    pkgs.writeShellScriptBin "disko-vm-persistent" ''
      set -euo pipefail

      state_dir="''${DISKO_VM_STATE_DIR:-''${XDG_DATA_HOME:-$HOME/.local/share}/disko-vm/${hostName}}"
      mkdir -p "$state_dir"
      export tmp="$state_dir"

      if [ "''${1:-}" = "--reset" ]; then
        echo "Resetting VM disk images in $state_dir..."
        ${lib.concatMapStringsSep "\n    " (
          name: ''rm -f "$state_dir"/${lib.escapeShellArg name}.qcow2''
        ) diskNames}
        shift
      fi

      ${lib.concatMapStringsSep "\n    " (name: ''
        if [ ! -f "$state_dir"/${lib.escapeShellArg name}.qcow2 ]; then
          echo "Creating persistent disk overlay: $state_dir/${name}.qcow2"
          ${lib.getExe' pkgs.qemu "qemu-img"} create -f qcow2 \
            -b ${diskoImages}/${lib.escapeShellArg name}.qcow2 \
            -F qcow2 "$state_dir"/${lib.escapeShellArg name}.qcow2
        fi'') diskNames}

      exec ${vmRunner}/bin/run-*-vm "$@"
    '';

  # Propagate neededForBoot filesystems and enable serial console in VM variant
  virtualisation.vmVariantWithDisko.virtualisation = {
    fileSystems = lib.pipe config.fileSystems [
      (lib.filterAttrs (_: fs: fs.neededForBoot))
      (lib.mapAttrs (_: _: { neededForBoot = true; }))
    ];
    qemu.options = [
      "-serial"
      "stdio"
    ];
  };
}
