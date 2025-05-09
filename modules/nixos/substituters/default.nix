{ lib, pkgs, config, ... }:

{
  # TODO: custom option?
  nix.settings = lib.foldl'
    (acc: { substituter, public-key }: {
      substituters = acc.substituters ++ [ substituter ];
      trusted-public-keys = acc.trusted-public-keys ++ [ public-key ];
    })
    {
      substituters = [];
      trusted-public-keys = [];
    }
    [
      {
        substituter = "https://rix101.cachix.org";
        public-key = "rix101.cachix.org-1:2u9ZGi93zY3hJXQyoHkNBZpJK+GiXQyYf9J5TLzCpFY=";
      }
      {
        substituter = "https://nix-community.cachix.org";
        public-key = "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=";
      }
      {
        substituter = "https://lean4.cachix.org";
        public-key = "lean4.cachix.org-1:mawtxSxcaiWE24xCXXgh3qnvlTkyU7evRRnGeAhD4Wk=";
      }
      {
        substituter = "https://nixpkgs-cross-overlay.cachix.org";
        public-key = "nixpkgs-cross-overlay.cachix.org-1:TjKExGN4ys960TlsGqNOI/NBdoz2Jdr2ow1VybWV5JM=";
      }
      # {
      #   substituter = "https://cache.ngi0.nixos.org";
      #   public-key = "cache.ngi0.nixos.org-1:KqH5CBLNSyX184S9BKZJo1LxrxJ9ltnY2uAs5c/f1MA=";
      # }
    ];
}
