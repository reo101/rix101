{ inputs, lib, ... }:

{ pkgs, ... }:

{
  nix = {
    package = lib.mkDefault pkgs.nixVersions.latest;

    registry = import ../../../nix/registry.nix { inherit lib inputs; };

    settings = {
      experimental-features = lib.mkDefault [
        "nix-command"
        "flakes"
      ];

      substituters = lib.mkBefore [
        "https://nix-community.cachix.org"
        "https://rix101.cachix.org"
      ];
      trusted-public-keys = lib.mkBefore [
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "rix101.cachix.org-1:2u9ZGi93zY3hJXQyoHkNBZpJK+GiXQyYf9J5TLzCpFY="
      ];

      auto-optimise-store = lib.mkDefault true;
      keep-outputs = lib.mkDefault true;
      keep-derivations = lib.mkDefault true;
    };
  };
}
