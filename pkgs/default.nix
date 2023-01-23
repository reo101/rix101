# Custom packages, that can be defined similarly to ones from nixpkgs
# You can build them using 'nix build .#example' or (legacy) 'nix-build -A example'

{ nixpkgs ? (import ../nixpkgs.nix) { } }: rec {
  # example = pkgs.callPackage ./example { };
  opentype-feature-freezer = nixpkgs.callPackage ./opentype-feature-freezer {
    lib = nixpkgs.lib;
    python3 = nixpkgs.python3;
  };
  firacode-patched = nixpkgs.callPackage ./firacode-patched {
    inherit nixpkgs opentype-feature-freezer;
  };
}
