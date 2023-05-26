# Custom packages, that can be defined similarly to ones from nixpkgs
# You can build them using 'nix build .#example' or (legacy) 'nix-build -A example'

{ pkgs ? (import ../nixpkgs.nix) { }
, ...
}: {
  # example = pkgs.callPackage ./example { };
  advcp = pkgs.callPackage ./advcp { };
  fennel-language-server = pkgs.callPackage ./fennel-language-server { };
  parinfer-rust = pkgs.callPackage ./parinfer-rust { };
  swww = pkgs.callPackage ./swww { };
  vim-fmi-cli = pkgs.callPackage ./vim-fmi-cli { };
  win2xcur = pkgs.callPackage ./win2xcur { };
}
