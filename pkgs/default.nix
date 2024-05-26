# Custom packages, that can be defined similarly to ones from nixpkgs
# You can build them using 'nix build .#example' or (legacy) 'nix-build -A example'

{ pkgs ? (import ../nixpkgs.nix) { }
, ...
}: {
  # example = pkgs.callPackage ./example { };
  advcpmv = pkgs.callPackage ./advcpmv { };
  circom = pkgs.callPackage ./circom { };
  circom-lsp = pkgs.callPackage ./circom-lsp { };
  envsub = pkgs.callPackage ./envsub { };
  fennel-language-server = pkgs.callPackage ./fennel-language-server { };
  parinfer-rust = pkgs.callPackage ./parinfer-rust { };
  pest-ide-tools = pkgs.callPackage ./pest-ide-tools { };
  # FIXME: only buildable on darwin
  # pngpaste = pkgs.callPackage ./pngpaste { };
  srtool-cli = pkgs.callPackage ./srtool-cli { };
  swww = pkgs.callPackage ./swww { };
  vim-fmi-cli = pkgs.callPackage ./vim-fmi-cli { };
  win2xcur = pkgs.callPackage ./win2xcur { };
}
