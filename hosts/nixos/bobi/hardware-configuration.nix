# Do not modify this file!  It was generated by ‘nixos-generate-config’
# and may be overwritten by future invocations.  Please make changes
# to /etc/nixos/configuration.nix instead.
{ config, lib, pkgs, modulesPath, ... }:

{
  imports =
    [ (modulesPath + "/installer/scan/not-detected.nix")
    ];

  boot.initrd.availableKernelModules = [ "xhci_pci" "nvme" "usbhid" "usb_storage" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.kernelParams = [ "intel_pstate=active" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" =
    { device = "/dev/disk/by-uuid/8226bbff-1325-4388-aec8-d39e2affb9dc";
      fsType = "btrfs";
      options = [ "subvol=root" ];
    };

  fileSystems."/home" =
    { device = "/dev/disk/by-uuid/8226bbff-1325-4388-aec8-d39e2affb9dc";
      fsType = "btrfs";
      options = [ "subvol=home" ];
    };

  fileSystems."/nix" =
    { device = "/dev/disk/by-uuid/8226bbff-1325-4388-aec8-d39e2affb9dc";
      fsType = "btrfs";
      options = [ "subvol=nix" ];
    };

  fileSystems."/boot/efi" =
    { device = "/dev/disk/by-uuid/5F66-17ED";
      fsType = "vfat";
      options = [ "fmask=0022" "dmask=0022" ];
    };

  fileSystems."/data" =
    { device = "/dev/disk/by-uuid/67D4-ABDC";
      fsType = "exfat";
    };

  swapDevices =
    [ { device = "/dev/disk/by-uuid/39cc7c76-7709-4e4c-9d89-2037757df077"; }
    ];

  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  # (the default) this is the recommended approach. When using systemd-networkd it's
  # still possible to use this option, but it's recommended to use it in conjunction
  # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
  networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.enp4s0f1u1.useDHCP = lib.mkDefault true;
  # networking.interfaces.wlp5s0.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
