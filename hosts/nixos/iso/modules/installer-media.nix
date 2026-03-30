{
  lib,
  pkgs,
  ...
}:
{
  documentation = {
    # From `nixpkgs/nixos/modules/profiles/installation-device.nix`
    enable = lib.mkImageMediaOverride true;
    # From `nixpkgs/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix`
    doc.enable = lib.mkOverride 500 true;
    # From `nixpkgs/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix`
    man.enable = lib.mkOverride 500 true;
    # From `nixpkgs/nixos/modules/profiles/installation-device.nix`
    nixos.enable = lib.mkImageMediaOverride true;
  };

  # From `nixpkgs/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix`
  fonts.fontconfig.enable = lib.mkOverride 500 false;

  # From `nixpkgs/nixos/modules/installer/cd-dvd/installation-cd-base.nix`
  boot.loader.grub.memtest86.enable = true;
  # From `nixpkgs/nixos/modules/profiles/installation-device.nix`
  boot.kernel.sysctl."vm.overcommit_memory" = "1";

  hardware = {
    # From `nixpkgs/nixos/modules/installer/cd-dvd/installation-cd-base.nix`
    enableAllHardware = true;
    # Equivalent to `nixpkgs/nixos/modules/installer/scan/detected.nix`
    enableRedistributableFirmware = lib.mkDefault true;
  };

  # From `nixpkgs/nixos/modules/installer/cd-dvd/installation-cd-base.nix`
  environment.defaultPackages = [ pkgs.rsync ];
  # From `nixpkgs/nixos/modules/profiles/installation-device.nix`
  environment.variables.GC_INITIAL_HEAP_SIZE = "1M";

  isoImage = {
    # From `nixpkgs/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix`
    edition = lib.mkOverride 500 "minimal";
    # From `nixpkgs/nixos/modules/installer/cd-dvd/installation-cd-base.nix`
    makeEfiBootable = true;
    # From `nixpkgs/nixos/modules/installer/cd-dvd/installation-cd-base.nix`
    makeUsbBootable = true;
  };

  # From `nixpkgs/nixos/modules/installer/cd-dvd/installation-cd-base.nix`
  programs.git.enable = lib.mkDefault true;

  # From `nixpkgs/nixos/modules/profiles/installation-device.nix`
  system.nixos.variant_id = lib.mkDefault "installer";
}
