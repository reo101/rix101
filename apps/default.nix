# Custom apps, that can be defined similarly to ones from nixpkgs
# You can build them using 'nix run .#example'

{ pkgs ? (import ../nixpkgs.nix) { }
, ...
}: {
  # example = import ./example { inherit pkgs; };
}
